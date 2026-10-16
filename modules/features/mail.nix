{ ... }: {
  flake.nixosModules.mail = { pkgs, ... }: {
    environment.systemPackages = [
      pkgs.notmuch
      pkgs.lieer
    ];

    environment.etc."notmuch-config".text = ''
      [database]
      path=/home/kristian/.mail

      [user]
      name=Kristian Dam Pedersen
      primary_email=kristian.dam.pedersen@gmail.com

      [new]
      tags=
      ignore=/.*[.](json|lock|bak)$/;

      [search]
      exclude_tags=deleted;spam;trash;

      [maildir]
      synchronize_flags=true
    '';

    environment.sessionVariables.NOTMUCH_CONFIG = "/etc/notmuch-config";

    systemd.tmpfiles.rules = [
      "d /home/kristian/.mail 0700 kristian users -"
      "d /home/kristian/.mail/account.gmail 0700 kristian users -"
    ];
  };
}
