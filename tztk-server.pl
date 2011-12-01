#!/usr/bin/perl -w
use strict;

# This is tztk-server.pl from Topaz's Minecraft SMP Toolkit!
# Notes and new versions can be found at http://minecraft.topazstorm.com/

use IO::Select;
use IPC::Open2;
use IO::Handle;
use IO::Socket;
use File::Copy;
use POSIX qw(strftime);
use IO::Uncompress::Gunzip qw(gunzip);
use IO::Compress::Gzip qw(gzip);
use LWP::UserAgent;
use Encode;

my $protocol_version = 0x16;
my $client_version = 99;
my $server_memory = "1024M";

# client init
my %packet; %packet = (
  cs_long => sub { pack("N", unpack("L", pack("l", $_[0]))) },
  cs_short => sub { pack("n", unpack("S", pack("s", $_[0]))) },
  cs_string => sub { $packet{cs_short}(length $_[0]) . encode("UCS-2BE", decode("UTF-8",$_[0])) },
  sc_short => sub { unpack("s", pack("S", unpack("n", $_[0]))) },
  cs_keepalive => sub { #()
    chr(0x00);
  },
  cs_login => sub { #(user, pass)
    chr(0x01) . $packet{cs_long}($protocol_version)  . $packet{cs_string}($_[0]) . $packet{cs_string}($_[1]) . ("\0" x 14);
  },
  cs_disconnect => sub { #(reason)
    chr(0xff) . $packet{cs_string}($_[0]);
  },
  cs_handshake => sub { #(user)
    chr(0x02) . $packet{cs_string}($_[0]);
  },
  sc_readnext => sub { #(handle)
    sysread($_[0], (my $type), 1);
    return defined($type=$packet{sc_typemap}{ord($type)}) ? {type=>$type, $packet{$type}($_[0])} : undef;
  },
  sc_typemap => {
    0x02 => 'sc_handshake',
    0xff => 'sc_disconnect',
  },
  sc_handshake => sub {
    sysread($_[0], (my $len), 2);
    $len = $packet{sc_short}($len);
    sysread($_[0], (my $server_id), $len);
    return (server_id => $server_id);
  },
  sc_disconnect => sub {
    sysread($_[0], (my $len), 2);
    $len = $packet{sc_short}($len);
    sysread($_[0], (my $message), $len);
    return (message => $message);
  },
);

# localization init
my $tztk_dir = cat("tztk-dir") || "tztk";
require "$tztk_dir/L10N.pm";
my $l10n = L10N->get_handle() || die "Sorry, no usable language.";

my $cmddir = "$tztk_dir/allowed-commands";
my $snapshotdir = "$tztk_dir/snapshots";
my %msgcolor = (info => 36, warning => 33, error => 31, tztk => 32, chat => 35);

$|=1;
my $ua = new LWP::UserAgent; $ua->agent("tztk");

# load server properties
my %server_properties;
open(SERVERPROPERTIES, "server.properties") or die $l10n->maketext("failed to load server properties: [_1]", $!);
while (<SERVERPROPERTIES>) {
  next if /^\s*\#/;
  next unless /^\s*([\w\-]+)\s*\=\s*(.*?)\s*$/;
  my ($k, $v) = (lc $1, $2);
  $k =~ s/\-/_/g;
  $server_properties{$k} = $v;
}
close SERVERPROPERTIES;
$server_properties{server_ip} ||= "localhost";
$server_properties{server_port} ||= 25565;
print color(tztk => $l10n->maketext("Minecraft server appears to be at [_1]:[_2]\n", $server_properties{server_ip},$server_properties{server_port}));

# load waypoint authentication
my %wpauth;
if (-d "$tztk_dir/waypoint-auth") {
  $wpauth{username} = cat("$tztk_dir/waypoint-auth/username");
  $wpauth{password} = cat("$tztk_dir/waypoint-auth/password");
  my $sessiondata = mcauth_startsession($wpauth{username}, $wpauth{password});

  if (!ref $sessiondata) {
    print color(tztk => $l10n->maketext("Failed to authenticate with waypoint-auth user [_1]: [_2]\n", $wpauth{username}, $sessiondata));
    %wpauth = ();
  } else {
    $wpauth{username} = $sessiondata->{username};
    $wpauth{session_id} = $sessiondata->{session_id};
  }
}

# connect to irc
my $irc;
if (-d "$tztk_dir/irc") {
  $irc = irc_connect({
    host    => cat("$tztk_dir/irc/host")    || "localhost",
    port    => cat("$tztk_dir/irc/port")    || 6667,
    nick    => cat("$tztk_dir/irc/nick")    || "minecraft",
    channel => cat("$tztk_dir/irc/channel") || "#minecraft",
  });
}

# start minecraft server
my $server_pid = 0;
$SIG{PIPE} = sub { print color(error => "SIGPIPE (\$?=$?, k0=".(kill 0 => $server_pid).", \$!=$!)\n"); };
$server_pid = open2(\*MCOUT, \*MCIN, "java -Xmx$server_memory -Xms$server_memory -jar minecraft_server.jar nogui 2>&1");
MCOUT->blocking(0);
print $l10n->maketext("Minecraft SMP Server launched with pid [_1]\n", $server_pid);

my (@players, %payments_pending, $want_list, $shutdown_scheduled, $downtime_estimate);
my $last_time = 0;
my $next_snapshot_test = 0;
my $server_ready = 0;
my $want_snapshot = 0;

my $sel = new IO::Select(\*MCOUT, \*STDIN);
$sel->add($irc->{socket}) if $irc;

while (kill 0 => $server_pid) {
  foreach my $fh ($sel->can_read(1)) {
    if ($fh == \*STDIN) {
      my $stdin = <STDIN>;
      if (!defined $stdin) {
        # server is headless
        $sel->remove(\*STDIN);
        next;
      }
      if ($stdin =~ /^\-snapshot\s*$/) {
        snapshot_begin();
      } elsif($stdin =~ /^\-shutdown\s*([\-\d]*)\s*(\d*)/) {
        my $delay = $1 || 5;
        my $downtime = $2;
        if ($delay < 0) {
          $shutdown_scheduled and console_exec(say => $l10n->maketext("Shutdown cancelled."));
          $shutdown_scheduled = 0;
          next;
        } elsif ($delay > 180) {
          $delay = 180;
        }
        $shutdown_scheduled = time + ($delay*60);
        $downtime_estimate = $downtime;
      } else {
        print MCIN $stdin;
      }
    } elsif ($fh == \*MCOUT) {
      if (eof(MCOUT)) {
        print $l10n->maketext("Minecraft server seems to have shut down.  Exiting...\n") ;
        exit;
      }
      while (my $mc = <MCOUT>) {
        my ($msgprefix, $msgtype) = ("", "");
        # 2010-09-23 18:36:53 [INFO]
        ($msgprefix, $msgtype) = ($1, lc $2) if $mc =~ s/^([\d\-\s\:]*\[(\w+)\]\s*)//;
        $msgprefix = strftime('%F %T [MISC] ', localtime) unless length $msgprefix;
        $mc =~ s/\xc2\xa7[0-9a-f]//g; #remove color codes
        $msgtype = 'chat' if $msgtype eq 'info' && $mc =~ /^\<[\w\-\"\_]+\>\s+[^\-]/;
        print color($msgtype => $msgprefix.$mc);

        my ($cmd_user, $cmd_name, $cmd_args);

        # init messages
        # Done! For help, type "help" or "?"
        if ($mc =~ /^Done(?:\s*\(\w+\))?\!\s*For\s+help\,\s*type\b/) {
          $server_ready = 1;
          console_exec('list');
        # chat messages
        # <Username> Message text here
        } elsif ($mc =~ /^\<([\w\-\"\_]+)\>\s*(.+?)\s*$/) {
          my ($username, $msg) = ($1, $2);

          if ($msg =~ /^\-([\w\-\"\_]+)(?:\s+(.+?))?\s*$/) {
            ($cmd_user, $cmd_name, $cmd_args) = ($username, $1, $2);
          } else {
            irc_send($irc, "<$username> $msg") if $irc;
          }
        # whispers
        # 2011-01-08 21:24:10 [INFO] Topaz2078 whispers asdfasdf to nobody
        } elsif ($mc =~ /^([\w\-\"\_]+)\s+whispers\s+(.+?)\s+to\s+\-([\w\-\"\_]+)\s$/) {
          ($cmd_user, $cmd_name, $cmd_args) = ($1, $3, $2);
        # connection notices
        # Username [/1.2.3.4:5679] logged in with entity id 25
        } elsif ($mc =~ /^([\S]*?)?\s*\[\/([\d\.]+)\:\d+\]\s*logged\s+in\b/) {
          my ($username, $ip) = ($1, $2);

          if ($ip ne '127.0.0.1') {
            my ($whitelist_active, $whitelist_passed) = (0,0);
            if (-d "$tztk_dir/whitelisted-ips") {
              $whitelist_active = 1;
              $whitelist_passed = 1 if -e "$tztk_dir/whitelisted-ips/$ip";
            }
            if (-d "$tztk_dir/whitelisted-players") {
              $whitelist_active = 1;
              $whitelist_passed = 1 if -e "$tztk_dir/whitelisted-players/$username";
            }
            if ($whitelist_active && !$whitelist_passed) {
              console_exec(kick => $username);
              console_exec(say => $l10n->maketext("[_1] tried to join, but was not on any active whitelist", $username));
              next;
            }
          }

          irc_send($irc, $l10n->maketext("[_1] has connected", $username)) if $irc && player_is_human($username);

          if (player_is_human($username) && -e "$tztk_dir/motd" && open(MOTD, "$tztk_dir/motd")) {
            console_exec(tell => $username => $l10n->maketext("Message of the day:"));
            while (<MOTD>) {
              chomp;
              next unless /\S/;
              console_exec(tell => $username => $_);
            }
            close MOTD;
          }

          console_exec('list');
        # connection lost notices
        # Username lost connection: Quitting
        } elsif ($mc =~ /^([\w\-\"\_]+)\s+lost\s+connection\:\s*(.+?)\s*$/) {
          my ($username, $reason) = ($1, $2);
          irc_send($irc, $l10n->maketext("[_1] has disconnected: [_2]", $username, $reason)) if $irc && player_is_human($username);
          if (exists $payments_pending{$username}) {
            my $bank_dir = ensure_players_dir("bank", $username);
            my $mtime = 0;
            for (1..3) {
              sleep 1;
              $mtime = (stat("$server_properties{level_name}/players/$username.dat"))[9];
              last if time - $mtime < 3;
            }
            next unless time - $mtime < 3;
            my $player_nbt = read_player($username);
            next unless $player_nbt;
            my $modified_player = 0;
            foreach my $payment (@{$payments_pending{$username}}) {
              my %cost;
              my $cost_dir = "$tztk_dir/payment/$payment->{item}/cost";
              opendir(CDIR, $cost_dir);
              $cost{$_} = $payment->{amount} * cat("$cost_dir/$_") foreach grep {!/^\./} readdir CDIR;
              closedir CDIR;

              if (take_items($player_nbt, \%cost)) {
                my $payment_file = "$bank_dir/$payment->{item}";
                my $balance = cat($payment_file) || 0;
                $balance += $payment->{amount};
                open(BANKFILE, ">$payment_file");
                print BANKFILE $balance;
                close BANKFILE;
                $modified_player = 1;
              }
            }

            write_player($player_nbt, $username) if $modified_player;
            delete $payments_pending{$username};
          }
          console_exec('list');
        # player counts
        # Player count: 0
        } elsif ($mc =~ /^Player\s+count\:\s*(\d+)\s*$/) {
          # players.txt upkeep
          console_exec('list');
        # userlist players.txt update
        # Connected players: Topaz2078
        } elsif ($mc =~ /^Connected\s+players\:\s*(.*?)\s*$/) {
          @players = grep {/^[\w\-\"\_]+$/ && player_is_human($_)} split(/[^\w\-\"\_]+/, $1);
          if (defined $want_list) {
            console_exec(tell => $want_list => "Connected players: " . join(', ', @players));
            $want_list = undef;
          }
          open(PLAYERS, ">$tztk_dir/players.txt");
          print PLAYERS map{"$_\n"} @players;
          close PLAYERS;
        # snapshot save-complete trigger
        # CONSOLE: Save complete.
        } elsif ($mc =~ /^CONSOLE\:\s*Save\s+complete\.\s*$/) {
          if ($want_snapshot) {
            $want_snapshot = 0;
            snapshot_finish();
          }
        }

        if (defined $cmd_name && command_allowed($cmd_name)) {
          if (-e "$tztk_dir/payment/$cmd_name/cost") {
            my $bank_file = "$server_properties{level_name}/players/tztk/bank/$cmd_user/$cmd_name";
            my $paid = cat($bank_file);
            if (!$paid) {
              console_exec(tell => $cmd_user => $l10n->maketext("You must pay to use -[_1]!  (Try -buy-list to see what.)", $cmd_name));
              next;
            }

            $paid--;
            open(BANKFILE, ">$bank_file");
            print BANKFILE $paid;
            close BANKFILE;

            console_exec(tell => $cmd_user => $l10n->maketext("You have [quant,_1,more use,more uses] of -[_2] remaining.", $paid, $cmd_name));
          }
          if ($cmd_name eq 'seen' && $cmd_args =~ /^[\w\-\"\_]+$/) {
            my $query = $&;
            my @players = <$server_properties{level_name}/players/*.dat>;
            map { s/^.*\/(.*?)\.dat$/$1/ } @players;
            my @matches = grep(/$query/i,  @players);
            my $time = time;
            open(PLAYERS, "$tztk_dir/players.txt");
            my @connected = <PLAYERS>;
            close PLAYERS;
            foreach my $match (@matches) {
               player_is_human($match) or next;
               if (grep(/^$match$/, @connected)) {
                 console_exec(tell => $cmd_user => $l10n->maketext("[_1] is currently connected.", $match));
                 next;
               }
               my $mtime = (stat("$server_properties{level_name}/players/".$match.".dat"))[9];
               my $since = $time-$mtime;
               my ($days, $hours, $mins, $secs); 
               $days = int($since/(60*60*24));
               $since %= 60*60*24;
               $hours = int($since/(60*60));
               $since %= (60*60);
               $mins = int($since/60);
               $secs = $since % 60;
               console_exec(tell => $cmd_user => $l10n->maketext("[_1] hasn't been seen around since [quant,_2,day,days], [quant,_3,hour,hours], [quant,_4,minute,minutes], [quant,_5,second,seconds].",
                            $match, $days, $hours, $mins, $secs));
            }
            console_exec(tell => $cmd_user => $l10n->maketext("[_1] has never been seen around.", $query)) unless @matches;
          } elsif ($cmd_name eq 'help' && -e "$tztk_dir/help" && open(HELP, "$tztk_dir/help")) {
            while (<HELP>) {
              chomp;
              next unless /\S/;
              console_exec(tell => $cmd_user => $_);
            }
            close HELP;
          } elsif ($cmd_name eq 'create' && $cmd_args =~ /^(\d+)(?:\s*\D+?\s*(\d+))?|([a-z][\w\-\_]*)$/) {
            my ($id, $count, $kit) = ($1, $2||($3 ? 1:64), lc $3);
            my @create;
            if ($kit) {
              if (!-e "$cmddir/create/kits/$kit") {
                console_exec(tell => $cmd_user => $l10n->maketext("That is not a known kit."));
                next;
              }
              open(KIT, "$cmddir/create/kits/$kit");
              while (<KIT>) {
                next unless /^\s*(\d+)(?:\s*\D+?\s*(\d+))?\s*$/;
                push @create, [$1, $2||1];
              }

              if (!@create) {
                console_exec(tell => $cmd_user => $l10n->maketext("Nothing to create!  Is the kit defined correctly?"));
                next
              }
            } else {
              @create = ([$id, $count]);
            }

            foreach my $create (@create) {
              my ($id, $count) = @$create;
              $id = $id + 0;
              if (-d "$cmddir/create") {
                if (-d "$cmddir/create/whitelist" && !-e "$cmddir/create/whitelist/$id") {
                  console_exec(tell => $cmd_user => "Material $id is not in the active creation whitelist.");
                  next;
                }  elsif (-e "$cmddir/create/blacklist/$id") {
                  console_exec(tell => $cmd_user => "Material $id is in the creation blacklist.");
                  next;
                }
              }
              my $maxcreate = -e "$cmddir/create/max" ? cat("$cmddir/create/max") : 64;
              $count = $maxcreate if $count > $maxcreate;
              while ($count > 0) {
                my $amount = $count > 64 ? 64 : $count;
                $count -= $amount;
                console_exec(give => $cmd_user, $id, $amount);
              }
            }
          } elsif ($cmd_name eq 'tp' && $cmd_args =~ /^([\w\-\"\_]+)$/) {
            my ($dest) = ($1);
            console_exec(tp => $cmd_user, $dest);
          } elsif ($cmd_name eq 'wp' && $cmd_args =~ /^([\w\-\"\_]+)$/) {
            my $waypoint = "wp-" . lc($1);
            if (!-e "$server_properties{level_name}/players/$waypoint.dat") {
              console_exec(tell => $cmd_user => $l10n->maketext("That waypoint does not exist!"));
              next;
            }
            my $wp_user = $waypoint;
            if (%wpauth) {
              if (player_copy($waypoint, $wpauth{username})) {
                $wp_user = $wpauth{username};
              } else {
                console_exec(tell => $cmd_user => $l10n->maketext("Failed to adjust player data for authenticated user; check permissions of world files"));
                next;
              }
            }
            my $wp_player = player_create($wp_user);
            if (!ref $wp_player) {
              console_exec(tell => $cmd_user => $wp_player);
              next;
            }
            console_exec(tp => $cmd_user, $wp_user);
            player_destroy($wp_player);
            player_copy($wpauth{username}, $waypoint) if %wpauth;
          } elsif ($cmd_name eq 'wpp' && $cmd_args =~ /^([\w\-\"\_]+)$/) {
            my $waypoint = "pp-" . lc($1);
            if (length $waypoint > 16) {
              console_exec(tell => $cmd_user => $l10n->maketext("Maximum length for waypoint name is 13 characters."));
              next;
            } elsif (-e "$server_properties{level_name}/players/$waypoint.dat"){
              console_exec(tell => $cmd_user => $l10n->maketext("Can't use [_1] as dummy teleporter name : a player by that name already exists!", $waypoint));
              next;
            } elsif (!-e "$server_properties{level_name}/players/tztk/wpp/$cmd_user/$waypoint.dat") {
              console_exec(tell => $cmd_user => $l10n->maketext("That waypoint does not exist!"));
              next;
            }
            my $wp_user = %wpauth ? $wpauth{username} : $waypoint;
            if (not player_copy_from_private($waypoint, $wp_user, $cmd_user)) {
              console_exec(tell => $cmd_user => $l10n->maketext("Failed to adjust player data; check permissions of world files"));
              next;
            }
            my $wp_player = player_create($wp_user);
            if (!ref $wp_player) {
              console_exec(tell => $cmd_user => $wp_player);
              next;
            }
            console_exec(tp => $cmd_user, $wp_user);
            player_destroy($wp_player);
            player_move_to_private($wp_user, $waypoint, $cmd_user);
          } elsif ($cmd_name eq 'wp-set' && $cmd_args =~ /^([\w\-\"\_]+)$/) {
            my $waypoint = "wp-" . lc($1);
            if (length $waypoint > 16) {
                console_exec(tell => $cmd_user => $l10n->maketext("Maximum length for waypoint name is 13 characters."));
                next;
            }
            my $wp_user = $waypoint;
            if (%wpauth) {
              if (!-e "$server_properties{level_name}/players/$waypoint.dat" || player_copy($waypoint, $wpauth{username})) {
                $wp_user = $wpauth{username};
              } else {
                console_exec(tell => $cmd_user => $l10n->maketext("Failed to adjust player data for authenticated user; check permissions of world files"));
                next;
              }
            }
            my $wp_player = player_create($wp_user);
            if (!ref $wp_player) {
              console_exec(tell => $cmd_user => $wp_player);
              next;
            }
            console_exec(tp => $wp_user, $cmd_user);
            player_destroy($wp_player);
            player_copy($wpauth{username}, $waypoint) if %wpauth;
          } elsif ($cmd_name eq 'wpp-set' && $cmd_args =~ /^([\w\-\"\_]+)$/) {
            my $waypoint = "pp-" . lc($1);
            if (length $waypoint > 16) {
              console_exec(tell => $cmd_user => $l10n->maketext("Maximum length for waypoint name is 13 characters."));
              next;
            } elsif (-e "$server_properties{level_name}/players/$waypoint.dat"){
              console_exec(tell => $cmd_user => $l10n->maketext("Can't use [_1] as dummy teleporter name : a player by that name already exists!"));
              next;
            }
            ensure_players_dir("wpp", $cmd_user);
            my $wp_user = %wpauth ? $wpauth{username} : $waypoint;
            if (-e "$server_properties{level_name}/players/tztk/wpp/$cmd_user/$waypoint.dat" and not player_copy_from_private($waypoint, $wp_user, $cmd_user)) {
              console_exec(tell => $cmd_user => $l10n->maketext("Failed to adjust player data; check permissions of world files"));
              next;
            }
            my $wp_player = player_create($wp_user);
            if (!ref $wp_player) {
              console_exec(tell => $cmd_user => $wp_player);
              next;
            }
            console_exec(tp => $wp_user, $cmd_user);
            player_destroy($wp_player);
            if (!player_move_to_private($wp_user, $waypoint, $cmd_user)) {
               console_exec(tell => $cmd_user => "Failed to save.");
            }
          } elsif ($cmd_name eq 'wp-list') {
            opendir(PLAYERS, "$server_properties{level_name}/players/");
            console_exec(tell => $cmd_user => join(", ", sort map {/^wp\-([\w\-\"\_]+)\.dat$/ ? $1 : ()} readdir(PLAYERS)));
            closedir(PLAYERS);
          } elsif ($cmd_name eq 'wpp-list') {
            ensure_players_dir("wpp", $cmd_user);
            opendir(PLAYERS, "$server_properties{level_name}/players/tztk/wpp/$cmd_user");
            console_exec(tell => $cmd_user => join(", ", sort map {/^pp\-([\w\-\"\_]+)\.dat$/ ? $1 : ()} readdir(PLAYERS)));
            closedir(PLAYERS);
          } elsif ($cmd_name eq 'list') {
            console_exec('list');
            $want_list = $cmd_user;
          } elsif ($cmd_name eq 'buy' && $cmd_args =~ /^([\w\-\"\_]+)(?:\s+(\d+))$/) {
            my ($item, $amount) = ($1, $2||1);
            if (!-d "$tztk_dir/payment/$item/cost") {
              console_exec(tell => $cmd_user => $l10n->maketext("That item is not for sale!"));
              next;
            } else {
              push @{$payments_pending{$cmd_user}}, {
                item => $item,
                amount => $amount,
              };
              console_exec(tell => $cmd_user => $l10n->maketext("You will buy [_1] [_2] using items in your inventory the next time you log out.", $amount, $item));
            }
          } elsif ($cmd_name eq 'bank-list') {
            my $bank_dir = "$server_properties{level_name}/players/tztk/bank/$cmd_user";
            if (!-d $bank_dir) {
              console_exec(tell => $cmd_user => $l10n->maketext("You don't even have a bank!"));
              next;
            }

            my %bank;
            opendir(BANKDIR, $bank_dir);
            $bank{$_} = cat("$bank_dir/$_") foreach grep {!/^\./} readdir BANKDIR;
            closedir BANKDIR;

            delete $bank{$_} foreach grep {!$bank{$_}} keys %bank;

            if (!%bank) {
              console_exec(tell => $cmd_user => $l10n->maketext("Your bank is empty."));
              next;
            }

            console_exec(tell => $cmd_user => $l10n->maketext("Your bank: ") . join(", ", map {"$_($bank{$_})"} sort keys %bank));
          } elsif ($cmd_name eq 'buy-list') {
            my $pay_dir = "$tztk_dir/payment";
            my %cost;
            opendir(PDIR, $pay_dir);
            foreach my $item (grep {!/^\./} readdir(PDIR)) {
              my $cost_dir = "$pay_dir/$item/cost";
              opendir(CDIR, $cost_dir);
              $cost{$item}{$_} = cat("$cost_dir/$_") foreach grep {!/^\./} readdir CDIR;
              closedir CDIR;
            }
            closedir(PDIR);

            console_exec(tell => $cmd_user => join("; ", map {my $item = $_; "$item(" . join(", ", map {"$_($cost{$item}{$_})"} sort{$a<=>$b}keys %{$cost{$item}}) . ")"} sort keys %cost));
          }
        }
      } #/while(mcout)
    } elsif ($irc && $fh == $irc->{socket}) {
      if (!irc_read($irc)) {
        $sel->remove($irc->{socket});
        if ($irc = irc_connect($irc)) {
          $sel->add($irc->{socket});
        }
      }
    }
  } #foreach readable fh

  # snapshots
  my $snapshot_period;
  if (!$want_snapshot and (time > $next_snapshot_test) and $snapshot_period = cat("$tztk_dir/snapshot-period")) {
    $next_snapshot_test = time + 60;
    if ($snapshot_period =~ /^\d+$/) {
      mkdir $snapshotdir unless -d $snapshotdir;
      if (!-e "$snapshotdir/latest" || time - (stat("$snapshotdir/latest"))[9] >= $snapshot_period) {
        snapshot_begin();
      }
    }
  }

  # shutdown broadcast
  if ($shutdown_scheduled and time > $last_time) {
    $last_time = time;
    my $remaining = $shutdown_scheduled-$last_time;
    my $do_broadcast = 0;
    if (int($remaining/3600) > 0) {
      not $remaining%3600 and
        console_exec(say => $l10n->maketext("The server is going DOWN for maintenance in [quant,_1,hour,hours]. Estimated downtime: [quant,_2,minute,minutes,undefined]",
          int(($remaining+1)/3600), $downtime_estimate));
    } elsif (int($remaining/1800)>0) { $do_broadcast = not ($remaining%1800);}
      elsif (int($remaining/600)>0)  { $do_broadcast = not ($remaining%600);}
      elsif (int($remaining/300)>0)  { $do_broadcast = not ($remaining%300);}
      elsif (int($remaining/60)>0)   { $do_broadcast = not ($remaining%60);}
      elsif ($remaining <= 0 and !$want_snapshot) {
      $shutdown_scheduled = 0;
      console_exec('stop');
    }
    $do_broadcast and  console_exec(say => $l10n->maketext("The server is going DOWN for maintenance in [quant,_1,minute,minutes]. Estimated downtime: [quant,_2,minute,minutes,undefined]",
      int($remaining/60), $downtime_estimate));
  }

} continue {
  # in case of unexpected catastrophic i/o errors, yield to prevent spinlock
  select undef, undef, undef, .01;
}

print $l10n->maketext("Can no longer reach server at pid [_1]; is it dead?  Exiting...\n", $server_pid);

sub color {
  my ($color, $message) = (lc $_[0], $_[1]);
  my $rv = "";
  $rv .= "\e[$msgcolor{$color}m" if exists $msgcolor{$color};
  $rv .= $message;
  $rv .= "\e[0m" if exists $msgcolor{$color};
  return $rv;
}

sub snapshot_begin {
  return unless $server_ready;
  console_exec('save-off');
  console_exec('save-all');
  $want_snapshot = 1;
}

sub snapshot_finish {
  console_exec(say => $l10n->maketext("Creating snapshot..."));
  my $snapshot_name = strftime('snapshot-%Y-%m-%d-%H-%M-%S.tgz', localtime);
  my $tar_pid = open2(\*TAROUT, \*TARIN, "tar", "-czvhf", "$snapshotdir/$snapshot_name", '--', $server_properties{level_name});
  close TARIN;
  my $tar_count = 0;
  while (<TAROUT>) {
    $tar_count++;
  }
  waitpid $tar_pid, 0;
  close TAROUT;
  console_exec('save-on');
  unlink("$snapshotdir/latest");
  symlink("$snapshot_name", "$snapshotdir/latest");

  my $snapshot_max;
  if ($snapshot_max = cat("$tztk_dir/snapshot-max")) {
    if ($snapshot_max =~ /^\d+$/ && $snapshot_max >= 1) {
      opendir(SNAPSHOTS, $snapshotdir);
      my @snapshots = sort grep {/^snapshot\-[\d\-]+\.tgz$/} readdir(SNAPSHOTS);
      closedir(SNAPSHOTS);
      unlink "$snapshotdir/".shift(@snapshots) while @snapshots > $snapshot_max;
    }
  }

  console_exec(say => $l10n->maketext("Snapshot complete! (Saved [_1] files.)", $tar_count));
}

sub schedule_shutdown {
  my $delay = shift || 5;
  my $downtime = shift;
  my $shutdown_scheduled = shift;
  if ($delay < 0) {
    $shutdown_scheduled and console_exec(say => $l10n->maketext("Shutdown cancelled."));
    $shutdown_scheduled = 0;
    return;
  } elsif ($delay > 180) {
    $delay = 180;
  }
  return (time+$delay*60, $downtime, $shutdown_scheduled);
}

sub ensure_players_dir {
  my $tztk_dir = "$server_properties{level_name}/players/tztk";
  mkdir $tztk_dir unless -d $tztk_dir;
  foreach my $subdir(@_) {
    $tztk_dir .= "/$subdir";
    mkdir $tztk_dir unless -d $tztk_dir;
  }
  return $tztk_dir;
}

sub player_create {
  my $username = lc $_[0];
  return $l10n->maketext("can't create fake player, server must set online-mode=false or provide a real user in [_1]/waypoint-auth", $tztk_dir) unless %wpauth || $server_properties{online_mode} eq 'false';
  return $l10n->maketext("invalid name") unless $username =~ /^[\w\-\"\_]+$/;

  my $player = IO::Socket::INET->new(
    Proto     => "tcp",
    PeerAddr  => $server_properties{server_ip},
    PeerPort  => $server_properties{server_port},
  ) or return $l10n->maketext("can't connect: [_1]", $!);

  if (%wpauth) {
    print $player $packet{cs_handshake}($username);
    while (1) {
      my $packet = $packet{sc_readnext}($player);
      die $l10n->maketext("totally unexpected packet; did the protocol change?") unless defined $packet;
      return $packet->{message} if $packet->{type} eq 'sc_disconnect';
      if ($packet->{type} eq 'sc_handshake') {
        my $status = mcauth_joinserver($username, $wpauth{session_id}, $packet->{server_id});
        last if $status eq 'OK';
        return $status;
      }
    }
  }

  syswrite($player, $packet{cs_login}($username, ""));
  select undef, undef, undef, .5;
  syswrite($player, $packet{cs_keepalive}());
  return $player;
}

sub player_destroy {
  syswrite($_[0], $packet{cs_keepalive}());
  select undef, undef, undef, 1;
  syswrite($_[0], $packet{cs_disconnect}($_[0]||""));
  select undef, undef, undef, 1;
  close $_[0];
}

sub player_copy {
  my ($datafile, $username) = @_;
  my $user_dat = "$server_properties{level_name}/players/$username.dat";
  my $user_bkp = "$server_properties{level_name}/players/$username.bkp";
  my $data_dat = "$server_properties{level_name}/players/$datafile.dat";
  _player_copy($data_dat, $user_dat, $user_bkp);
}

sub player_copy_from_private {
  my ($datafile, $username, $user) = @_;
  my $user_dat = "$server_properties{level_name}/players/$username.dat";
  my $user_bkp = "$server_properties{level_name}/players/$username.bkp";
  my $data_dat = "$server_properties{level_name}/players/tztk/wpp/$user/$datafile.dat";
  _player_copy($data_dat, $user_dat, $user_bkp);
}

sub player_move_to_private {
  my ($datafile, $username, $user) = @_;
  my $user_dat = "$server_properties{level_name}/players/tztk/wpp/$user/$username.dat";
  my $data_bkp = "$server_properties{level_name}/players/$datafile.bkp";
  my $data_dat = "$server_properties{level_name}/players/$datafile.dat";
  _player_copy($data_dat, $user_dat, "") or return 0;
  if (%wpauth) {
    return -e $data_bkp and _player_copy($data_bkp, $data_dat, "");
  } else {
    return unlink $data_dat;
  }
}

sub _player_copy {
  my ($data_dat, $user_dat, $user_bkp) = @_;

  if (-e $user_dat) {
    if (-l $user_dat or not $user_bkp) {
      # remove the old link
      unlink $user_dat;
    } else {
      # original username exists, back up profile just in case
      return 0 unless rename $user_dat, $user_bkp;
    }
  }

  my $success = copy $data_dat, $user_dat;
}

sub player_is_human {
  return $_[0] !~ /^[wp]p\-/ && (!%wpauth || $_[0] ne $wpauth{username});
}

sub mcauth_startsession {
  my @gvd = split(/\:/, http('www.minecraft.net', '/game/getversion.jsp', 'user='.urlenc($_[0]).'&password='.urlenc($_[1]).'&version='.urlenc($client_version)));
  return join(':', @gvd) if @gvd < 4;
  return {version=>$gvd[0], download_ticket=>$gvd[1], username=>$gvd[2], session_id=>$gvd[3]};
}

sub mcauth_joinserver {
  return http('www.minecraft.net', '/game/joinserver.jsp?user='.urlenc($_[0]).'&sessionId='.urlenc($_[1]).'&serverId='.urlenc($_[2]));
}

sub command_allowed { -e "$tztk_dir/allowed-commands/$_[0]" }

sub console_exec {
  print MCIN join(" ", @_) . "\n";
}

sub cat {
  open(FILE, $_[0]) or return undef;
  chomp(my $line = <FILE>);
  close FILE;
  return $line;
}

sub irc_connect {
  my $conf = shift;

  print color(tztk => $l10n->maketext("Connecting to IRC...\n"));

  my $irc = irc_init($conf);

  if (!ref $irc) {
    print color(error => "$irc\n");
    return undef;
  }

  print $irc "JOIN $conf->{channel}\r\n";
  print color(tztk => $l10n->maketext("Connected to IRC successfully!\n"));

  $conf->{socket} = $irc;
  return $conf;
}

sub irc_init {
  my $conf = shift;

  my $irc = new IO::Socket::INET(
    PeerAddr => $conf->{host},
    PeerPort => $conf->{port},
    Proto    => 'tcp'
  ) or return $l10n->maketext("couldn't connect to irc server: [_1]", $!);

  print $irc "NICK $conf->{nick}\r\n";
  print $irc "USER $conf->{nick} 8 * :Minecraft-IRC proxy bot\r\n";

  while (<$irc>) {
    if (/^PING(.*)$/i) {
      print $irc "PONG$1\r\n";
    } elsif (/^\:[\w\-\.]+\s+004\b/) {
      last;
    } elsif (/^\:[w\-\.]+\s+433\b/) {
      return $l10n->maketext("couldn't connect to irc server: nick is in use");
    }
  }

  return $irc;
}

sub irc_read {
  my $irc = shift;

  my $socket = $irc->{socket};
  my $line = <$socket>;
  return 0 if !defined $line;

  if ($line =~ /^PING(.*)$/i) {
    print $socket "PONG$1\r\n";
  } elsif ($line =~ /^\:([^\!\@\s]+).*?\s+(.+?)\s+$/) {
    # messages
    my $nick = $1;
    my $cmd = $2;
    my @args;
    push @args, ($1||"").($2||"") while $cmd =~ s/^(?!\:)(\S+)\s|^\:(.+?)\s*$//;

    if (uc $args[0] eq 'PRIVMSG') {
      my ($channel, $msg) = @args[1,2];
      if ($msg =~ /^\s*\-list\s*$/) {
        irc_send($irc, $l10n->maketext("Connected players: ") . join(', ', @players));
      } else {
        console_exec(say => "<$nick> $args[2]");
      }
    } elsif (uc $args[0] eq 'JOIN') {
      console_exec(say => $l10n->maketext("[_1] has joined the IRC channel", $nick));
    } elsif (uc $args[0] eq 'PART') {
      console_exec(say => $l10n->maketext("[_1] has left the IRC channel", $nick));
    }
  }

  return 1;
}

sub irc_send {
  my ($irc, $msg) = @_;
  print {$irc->{socket}} "PRIVMSG $irc->{channel} :$msg\r\n";
}

sub urlenc {
  local $_ = $_[0];
  s/([^a-zA-Z0-9\ ])/sprintf("%%%02X",ord($1))/ge;
  s/\ /\+/g;
  return $_;
}

sub http {
  my ($host, $path, $post) = @_;

  my $req;

  if (defined $post) {
    $req = HTTP::Request->new(POST => "http://$host$path");
    $req->content_type('application/x-www-form-urlencoded');
    $req->content($post);
  } else {
    $req = HTTP::Request->new(GET => "http://$host$path");
  }

  my $res = $ua->request($req);
  return $res->is_success ? $res->decoded_content : "";
}

sub read_player {
  my ($player) = @_;
  my $file = "$server_properties{level_name}/players/$player.dat";
  return -e $file ? read_nbt($file) : undef;
}

sub write_player {
  my ($nbt, $player) = @_;
  my $file = "$server_properties{level_name}/players/$player.dat";

  if (-e $file) {
    my $dir = "$server_properties{level_name}/players/tztk";
    mkdir $dir unless -d $dir;
    $dir .= "/backups";
    mkdir $dir unless -d $dir;
    my $timestamp = strftime('%Y-%m-%d-%H-%M-%S', localtime);
    rename $file, "$dir/$player-$timestamp";
  }

  write_nbt($nbt, $file);
}

sub read_nbt {
  my ($filename) = @_;

  my $input;
  gunzip($filename => \$input);
  my ($name, $nbt) = read_named_tag({d=>$input,c=>0});
  return ref $nbt ? $nbt : undef;
}

sub write_nbt {
  my ($nbt, $filename) = @_;

  my $output;
  write_named_tag(\$output, "", $nbt);
  gzip(\$output => $filename);
}

sub read_named_tag {
  my $fh = shift;

  xsysread($fh, my $t, 1);
  $t = ord $t;
  return undef unless $t;
  my $n = read_tag_payload($fh, 8);
  my $e = {type=>$t, payload=>read_tag_payload($fh, $t)};
  return ($n, $e);
}

sub read_tag_payload {
  my ($fh, $type) = @_;

  my ($v, $l, $t);

  if ($type == 1) { #byte
    xsysread($fh, $v, 1);
    return unpack("c",$v);
  } elsif ($type == 2) { #short
    xsysread($fh, $v, 2);
    return unpack("s", pack("S", unpack("n", $v)));
  } elsif ($type == 3) { #int
    xsysread($fh, $v, 4);
    return unpack("l", pack("L", unpack("N", $v)));
  } elsif ($type == 4) { #long
    xsysread($fh, $v, 8);
  } elsif ($type == 5) { #float
    xsysread($fh, $v, 4);
    return unpack("f", pack("L", unpack("N", $v)));
  } elsif ($type == 6) { #double
    xsysread($fh, $v, 8);
  } elsif ($type == 7) { #byte_array
    my $l = read_tag_payload($fh, 3);
    xsysread($fh, $v, $l);
  } elsif ($type == 8) { #string
    $l = read_tag_payload($fh, 2);
    xsysread($fh, $v, $l);
  } elsif ($type == 9) { #list
    $t = read_tag_payload($fh, 1);
    $l = read_tag_payload($fh, 3);
    $v = {listtype=>$t, listdata=>[]};
    if ($l) {
      push @{$v->{listdata}}, read_tag_payload($fh, $t) for 1..$l;
    }
  } elsif ($type == 10) { #compound
    $v = {};
    while (1) {
      my ($k, $e) = read_named_tag($fh);
      last unless defined $k;
      $v->{$k} = $e;
    }
  }
  return $v;
}

sub xsysread {
  $_[1] = substr($_[0]{d}, $_[0]{c}, $_[2]);
  $_[0]{c} += $_[2];
}

sub write_named_tag {
  my ($fh, $name, $obj) = @_;

  xsyswrite($fh, chr($obj->{type}));
  write_tag_payload($fh, 8, $name);
  write_tag_payload($fh, $obj->{type}, $obj->{payload});
}

sub write_tag_payload {
  my ($fh, $type, $payload) = @_;

  if ($type == 0) { #end
    xsyswrite($fh, pack("c", 0));
  } elsif ($type == 1) { #byte
    xsyswrite($fh, pack("c", $payload));
  } elsif ($type == 2) { #short
    xsyswrite($fh, pack("n", unpack("S", pack("s", $payload))));
  } elsif ($type == 3) { #int
    xsyswrite($fh, pack("N", unpack("L", pack("l", $payload))));
  } elsif ($type == 4) { #long
    xsyswrite($fh, $payload);
  } elsif ($type == 5) { #float
    xsyswrite($fh, pack("N", unpack("L", pack("f", $payload))));
  } elsif ($type == 6) { #double
    xsyswrite($fh, $payload);
  } elsif ($type == 7) { #byte_array
    write_tag_payload($fh, 3, length($payload));
    xsyswrite($fh, $payload);
  } elsif ($type == 8) { #string
    write_tag_payload($fh, 2, length($payload));
    xsyswrite($fh, $payload);
  } elsif ($type == 9) { #list
    write_tag_payload($fh, 1, $payload->{listtype});
    write_tag_payload($fh, 3, scalar(@{$payload->{listdata}}));
    foreach my $listdata (@{$payload->{listdata}}) {
      write_tag_payload($fh, $payload->{listtype}, $listdata);
    }
  } elsif ($type == 10) { #compound
    foreach my $name (keys %$payload) {
      write_named_tag($fh, $name, $payload->{$name});
    }
    write_tag_payload($fh, 0);
  }
}

sub xsyswrite {
  ${$_[0]} .= $_[1];
}

sub take_items {
  my $nbt = shift;
  my %cost = %{shift()};

  my %inv_count;

  foreach my $inv (@{$nbt->{payload}{Inventory}{payload}{listdata}}) {
    $inv_count{$inv->{id}{payload}} += $inv->{Count}{payload};
  }

  foreach my $id (keys %cost) {
    return 0 unless $inv_count{$id} >= $cost{$id};
  }

  my $listdata = $nbt->{payload}{Inventory}{payload}{listdata};
  for (my $i=$#$listdata; $i>=0; $i--) {
    next unless $cost{$listdata->[$i]{id}{payload}};
    $listdata->[$i]{Count}{payload} -= $cost{$listdata->[$i]{id}{payload}};
    $cost{$listdata->[$i]{id}{payload}} = $listdata->[$i]{Count}{payload} < 0 ? -$listdata->[$i]{Count}{payload} : 0;
    delete $listdata->[$i] if $listdata->[$i]{Count}{payload} < 1;
  }

  return 1;
}
