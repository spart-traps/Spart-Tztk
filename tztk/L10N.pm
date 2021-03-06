# strings extracted with something as crude as
# cat tztk-server.pl | perl -ne '/maketext\(\"(.*?)"/ && print "    \"$1\" => \"\",\n"' > strings

package L10N;
use base qw(Locale::Maketext);
1;

package L10N::en_us;
use base qw(L10N);
%Lexicon = ( '_AUTO' => 1, );
1;

package L10N::fr;
use base qw(L10N);
%Lexicon = ( '_AUTO' => 1,
    "failed to load server properties: [_1]" => "impossible de charger le fichier server.properties: [_1]",
    "Minecraft server appears to be at [_1]:[_2]\n" => "Le serveur Minecraft semble être à l'adresse [_1]:[_2]\n",
    "Failed to authenticate with waypoint-auth user [_1]: [_2]\n" => "Impossible de s'identifier avec l'utilisateur waypoint-auth [_1]: [_2]\n",
    "Minecraft SMP Server launched with pid [_1]\n" => "Le serveur SMP Minecraft s'est lancé avec le pid [_1]\n",
    "Minecraft server seems to have shut down.  Exiting...\n" => "Le serveur Minecraft semble s'être arrêté. Sortie...\n",
    "[_1] tried to join, but was not on any active whitelist" => "[_1] a essayé de s'identifier, mais il n'était inscrit dans aucune des whitelist actives",
    "[_1] tried to join, but didn't use an IP allowed for this username." => "[_1] a essayé de s'identifier avec une IP qui n'est pas autorisée pour ce nom d'utilisateur.",
    "[_1] has connected" => "[_1] s'est connecté",
    "Message of the day:" => "Message du jour :",
    "[_1] has disconnected: [_2]" => "[_1] s'est déconnecté: [_2]",
    "You must pay to use -[_1]!  (Try -buy-list to see what.)" => "Vous devez payer pour utiliser -[_1] ! (Essayez -buy-list pour voir les tarifs.)",
    "You have [quant,_1,more use,more uses] of -[_2] remaining." => "Vous pouvez encore utiliser -[_2] [_1] fois.",
    "[_1] is currently connected." => "[_1] est connecté(e) en ce moment même.",
    "[_1] hasn't been seen around since [quant,_2,day,days], [quant,_3,hour,hours], [quant,_4,minute,minutes], [quant,_5,second,seconds]." => "[_1] n'a pas été vu(e) depuis [quant,_2,jour,jours], [quant,_3,heure,heures], [quant,_4,minute,minutes] et [quant,_5,seconde,secondes].",
    "[_1] has never been seen around." => "[_1] n'a jamais été vu(e) par ici.",
    "Message [_1] deleted." => "Message [_1] effacé.",
    "Message number [_1] does not exist." => "Le message numéro [_1] n'existe pas.",
    "All messages deleted." => "Tous les messages ont été effacés.",
    "Syntax: '-del-msg <number>' to delete 1 message or '-del-msg' to delete all messages." => "Syntaxe : '-del-msg <numéro>' pour effacer un message, '-del-msg' pour effacer tous les messages.",
    "You don't have any message." => "Vous n'avez aucun message.",
    "*** End of messages ; use '-del-msg' or '-del-msg <number>' to delete old messages." => "*** Fin des messages. Utilisez '-del-msg <numéro>' ou '-del-msg' pour effacer un/tous message(s).",
    "Message from [_1]: " => "Message de [_1] : ",
    "Will tell [_1] he has messages waiting." => "[_1] sera prévenu(e) que des messages l'attendent.",
    "*** You have messages. Type '-msg' to read." => "*** Vous avez des messages. Tapez '-msg' pour les lire.",
    "No player by the name of '[_1]'." => "Pas de joueur nommé '[_1]'.",
    "Did you mean '[_1]'?" => "Vous vouliez peut-être écrire '[_1]' ?",
    "Syntax: '-msg <Username> <Message>' to post ; '-msg' to read." => "Syntaxe : '-msg <Joueur> <Message>' pour poster ; '-msg' pour lire.",
    "That is not a known kit." => "Ce nom de kit est inconnu.",
    "Nothing to create!  Is the kit defined correctly?" => "Rien à fabriquer ! Est-ce que le kit est correctement défini ?",
    "That waypoint does not exist!" => "Ce repère n'existe pas !",
    "Failed to adjust player data for authenticated user; check permissions of world files" => "Impossible de modifier les données de jeu de l'utilisateur authentifié ; vérifiez les permission des fichiers du monde",
    "Failed to adjust player data for authenticated user; check permissions of world files" => "Impossible de modifier les données d'un joueur ; vérifiez les permission des fichiers du monde",
    "Maximum length for waypoint name is 13 characters." => "La longueur maximum d'un nom de repère est de 13 caractères.",
    "Can't use [_1] as dummy teleporter name : a player by that name already exists!" => "Impossible d'utiliser [_1] comme repère de téléporteur : un joueur portant ce nom existe déjà !",
    "That item is not for sale!" => "Cette commande n'est pas à vendre !",
    "You will buy [_1] [_2] using items in your inventory the next time you log out." => "A la prochaine déconnexion, vous paierez [_1] [_2] avec des items de votre inventaire.",
    "You don't even have a bank!" => "Vous n'avez jamais rien acheté !",
    "Your bank is empty." => "Votre réserve de commandes est vide.",
    "Your bank: " => "Votre réserve : ",
    "The server is going DOWN for maintenance in [quant,_1,hour,hours]. Estimated downtime: [quant,_2,minute,minutes,undefined]" => "Le serveur s'éteindra pour maintenance dans [quant,_1,heure,heures]. Temps d'arrêt estimé : [quant,_2,minute,minutes,indéfini]",
    "The server is going DOWN for maintenance in [quant,_1,minute,minutes]. Estimated downtime: [quant,_2,minute,minutes,undefined]" => "Le serveur s'éteindra pour maintenance dans [quant,_1,minute,minutes]. Temps d'arrêt estimé : [quant,_2,minute,minutes,indéfini]",
    "Can no longer reach server at pid [_1]; is it dead?  Exiting...\n" => "Serveur injoignable sur le pid [_1] ; planté peut-être ? Fin du programme...",
    "Creating snapshot..." => "Sauvegarde en cours...", 
    "Snapshot complete! (Saved [_1] files.)" => "Sauvegarde terminée ! ([_1] fichiers.)",
    "can't create fake player, server must set online-mode=false or provide a real user in [_1]/waypoint-auth" => "Impossible de simuler un joueur : configurez le serveur en online-mode=false, ou indiquez les identifiants d'un véritable joueur dans [_1]/waypoint-auth.",
    "invalid name" => "ce nom n'est pas valide",
    "can't connect: [_1]" => "connexion impossible : [_1]",
    "totally unexpected packet; did the protocol change?" => "Paquet inattendu ; le protocole aurait-il changé ?",
    "Connecting to IRC...\n" => "Connexion au serveur IRC...\n",
    "Connected to IRC successfully!\n" => "Connexion au serveur IRC réussie !\n",
    "couldn't connect to irc server: [_1]" => "Impossible de se connecter au serveur IRC : [_1]",
    "couldn't connect to irc server: nick is in use" => "Impossible de se connecter au serveur IRC : pseudonyme déjà pris",
    "Connected players: " => "joueurs connectés : ",
    "[_1] has joined the IRC channel" => "[_1] a rejoint le canal IRC",
    "[_1] has left the IRC channel" => "[_1] a quitté le canal IRC"
);
1;

# template for translators of new languages :
=for TRANSLATOR

package L10N::your_language;
use base qw(L10N);
%Lexicon = ( '_AUTO' => 1,
    "failed to load server properties: [_1]" => "",
    "Minecraft server appears to be at [_1]:[_2]\n" => "",
    "Failed to authenticate with waypoint-auth user [_1]: [_2]\n" => "",
    "Maximum length for waypoint name is 13 characters." => "",
    "Can't use [_1] as dummy teleporter name : a player by that name already exists!" => "",
    "Minecraft SMP Server launched with pid [_1]\n" => "",
    "Minecraft server seems to have shut down.  Exiting...\n" => "",
    "[_1] tried to join, but was not on any active whitelist" => "",
    "[_1] tried to join, but didn't use an IP allowed for this username." => "",
    "[_1] has connected" => "",
    "Message of the day:" => "",
    "[_1] has disconnected: [_2]" => "",
    "You must pay to use -[_1]!  (Try -buy-list to see what.)" => "",
    "You have [quant,_1,more use,more uses] of -[_2] remaining." => "",
    "[_1] is currently connected." => "",
    "[_1] hasn't been seen around since [quant,_2,day,days], [quant,_3,hour,hours], [quant,_4,minute,minutes], [quant,_5,second,seconds]." => "",
    "[_1] has never been seen around." => "",
    "Message [_1] deleted." => "",
    "Message number [_1] does not exist." => "",
    "All messages deleted." => "",
    "Syntax of -del-msg command: '-del-msg <number>' to delete 1 message or '-del-msg' to delete all messages." => "",
    "You don't have any message." => "",
    "*** End of messages ; use '-del-msg' or '-del-msg <number>' to delete old messages." => "",
    "Message from [_1]: " => "",
    "Will tell [_1] he has messages waiting." => "",
    "*** You have messages. Type '-msg' to read." => "",
    "No player by the name of '[_1]'." => "",
    "Did you mean '[_1]'?" => "",
    "Syntax of -msg command: '-msg <Username> <Message>' to post ; '-msg' to read." => "",
    "That is not a known kit." => "",
    "Nothing to create!  Is the kit defined correctly?" => "",
    "That waypoint does not exist!" => "",
    "Failed to adjust player data for authenticated user; check permissions of world files" => "",
    "Failed to adjust player data ; check permissions of world files" => "",
    "That item is not for sale!" => "",
    "You don't even have a bank!" => "",
    "You will buy [_1] [_2] using items in your inventory the next time you log out." => "",
    "Your bank is empty." => "",
    "Your bank: " => "",
    "The server is going DOWN for maintenance in [quant,_1,hour,hours]. Estimated downtime: [quant,_2,minute,minutes,undefined]" => "",
    "The server is going DOWN for maintenance in [quant,_1,minute,minutes]. Estimated downtime: [quant,_2,minute,minutes,undefined]" => "",
    "Can no longer reach server at pid [_1]; is it dead?  Exiting...\n" => "",
    "Creating snapshot..." => "",
    "Snapshot complete! (Saved [_1] files.)" => "",
    "can't create fake player, server must set online-mode=false or provide a real user in [_1]/waypoint-auth" => "",
    "invalid name" => "",
    "can't connect: [_1]" => "",
    "totally unexpected packet; did the protocol change?" => "",
    "Connecting to IRC...\n" => "",
    "Connected to IRC successfully!\n" => "",
    "couldn't connect to irc server: [_1]" => "",
    "couldn't connect to irc server: nick is in use" => "",
    "Connected players: " => "",
    "[_1] has joined the IRC channel" => "",
    "[_1] has left the IRC channel" => ""
);
1;

=cut
