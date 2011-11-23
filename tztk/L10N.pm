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
    "[_1] has connected" => "[_1] s'est connecté",
    "Message of the day:" => "Message du jour :",
    "[_1] has disconnected: [_2]" => "[_1] s'est déconnecté: [_2]",
    "You must pay to use -[_1]!  (Try -buy-list to see what.)" => "Vous devez payer pour utiliser -[_1] ! (Essayez -buy-list pour voir les tarifs.)",
    "You have [_1] more [quant, _1, use, uses] of -[_2] remaining." => "Vous pouvez encore utiliser -[_2] [_1] fois.",
    "That is not a known kit." => "Ce nom de kit est inconnu.",
    "Nothing to create!  Is the kit defined correctly?" => "Rien à fabriquer ! Est-ce que le kit est correctement défini ?",
    "That waypoint does not exist!" => "Ce repère n'existe pas !",
    "Failed to adjust player data for authenticated user; check permissions of world files" => "Impossible de modifier les données de jeu de l'utilisateur authentifié ; vérifiez les permission des fichiers du monde",
    "That item is not for sale!" => "Cette commande n'est pas à vendre !",
    "You will buy [_1] [_2] using items in your inventory the next time you log out." => "A la prochaine déconnewion, vous paierez [_1] [_2] avec des items de votre inventaire.",
    "Your bank is empty." => "Votre réserve de commandes est vide.",
    "Your bank: " => "Votre réserve : ",
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
    "Minecraft SMP Server launched with pid [_1]\n" => "",
    "Minecraft server seems to have shut down.  Exiting...\n" => "",
    "[_1] tried to join, but was not on any active whitelist" => "",
    "[_1] has connected" => "",
    "Message of the day:" => "",
    "[_1] has disconnected: [_2]" => "",
    "You must pay to use -[_1]!  (Try -buy-list to see what.)" => "",
    "You have [_1] more [quant, _1, use, uses] of -[_2] remaining." => "",
    "That is not a known kit." => "",
    "Nothing to create!  Is the kit defined correctly?" => "",
    "That waypoint does not exist!" => "",
    "Failed to adjust player data for authenticated user; check permissions of world files" => "",
    "Failed to adjust player data for authenticated user; check permissions of world files" => "",
    "That item is not for sale!" => "",
    "You will buy [_1] [_2] using items in your inventory the next time you log out." => "",
    "Your bank is empty." => "",
    "Your bank: " => "",
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
