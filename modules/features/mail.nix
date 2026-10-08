{ ... }: {
  flake.nixosModules.mail = { pkgs, ... }: {
                          environment.systemPackages = [
                                                     pkgs.notmuch
                                                     pkgs.lieer

                                                     (pkgs.writeShellApplication {
                                                                                 name = "gmail-init";
                                                                                 runtimeInputs = [ pkgs.notmuch pkgs.lieer pkgs.coreutils ];
                                                                                 text = ''
                                                                                      umask 077
                                                                                      mkdir -p "$HOME/.mail/account.gmail"

                                                                                      notmuch new

                                                                                      cd "$HOME/.mail/account.gmail"
                                                                                      if [[ ! -e .gmailieer.json ]]; then
                                                                                         gmi init --no-auth kristian.dam.pedersen@gmail.com
                                                                                      fi

                                                                                      gmi set --no-remove-local-messages
                                                                                 '';
                                                     })
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
