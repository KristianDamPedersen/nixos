# NixOS

Install the prepared `laptop` host. Backups, secrets, and the host configuration
are assumed ready and pushed to GitHub.

## 1. Installer

Boot the NixOS USB in UEFI mode and connect to the network (`nmtui` if needed).
Run the installer steps as root:

```bash
sudo -i
loadkeys dk-latin1
export NIX_CONFIG='experimental-features = nix-command flakes'
nix shell nixpkgs#git nixpkgs#neovim

git clone https://github.com/KristianDamPedersen/nixos.git /tmp/nixos
cd /tmp/nixos
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINTS
ls -l /dev/disk/by-id/
test -d /sys/firmware/efi
free -h
```

Set the whole disk's `/dev/disk/by-id/...` path in
`modules/hosts/laptop/disks.nix`. In `configuration.nix`, replace the swap-size
placeholder with **about 50% of RAM in MiB**; for 32 GiB RAM:

```nix
size = 16 * 1024;
```

Generate the hardware file at the path imported by `laptop/hardware.nix`:

```bash
nixos-generate-config --no-filesystems --show-hardware-config \
  > config/hardware/laptop-hardware.nix
git add config/hardware/laptop-hardware.nix modules/hosts/laptop
nix flake check --no-build
nix eval --raw .#nixosConfigurations.laptop.config.disko.devices.disk.main.device
```

## 2. Format and install

**The disk script erases the selected disk.** Verify the path above before running:

```bash
nix build .#nixosConfigurations.laptop.config.system.build.diskoScript \
  --out-link /tmp/disko-laptop
/tmp/disko-laptop
findmnt -R /mnt
```

Enter a disk-encryption passphrase. Check that `/mnt` is encrypted ext4 and
`/mnt/boot` is FAT, then install:

```bash
nixos-generate-config --root /mnt --no-filesystems --show-hardware-config \
  > config/hardware/laptop-hardware.nix
git add config/hardware/laptop-hardware.nix
mkdir -p /mnt/etc/nixos
cp -a /tmp/nixos/. /mnt/etc/nixos/
nixos-install --flake /mnt/etc/nixos#laptop
nixos-enter --root /mnt -c 'passwd kristian'
nixos-enter --root /mnt -c 'chown -R kristian:users /etc/nixos'
reboot
```

Set the root password when `nixos-install` prompts. Remove the USB, unlock the
disk, and log in as `kristian`. Select Niri at the login screen.

## 3. Authenticate

Run everything below as `kristian`. Open Kitty with `Super+Return`.

Sign into the 1Password desktop app and enable:

- Security → Unlock using system authentication.
- Developer → Integrate with 1Password CLI.

```bash
op signin
op whoami
gh auth login --hostname github.com --git-protocol https --web
gh auth setup-git
gh auth status

ss() {
  secretspec --file /etc/nixos/config/doom/secretspec.toml "$@" \
    --profile default --provider onepassword://Private
}
ss get TEST_SECRET > /dev/null
```

## 4. Restore Org keys and notes

```bash
umask 077
mkdir -p ~/.gnupg
chmod 700 ~/.gnupg
gpg --import /etc/nixos/config/doom/keys/org-public.asc
ss get ORG_GPG_RECOVERY_PRIVATE_KEY | gpg --import
gpg --list-secret-keys --with-fingerprint
```

Verify the recovery private key fingerprint:
`5B68574315AA1860B7C329B3B65B8EB671FAA22F`.

Mark both verified public keys as trusted. For each command, enter `trust`,
choose `5` (ultimate), confirm, then `quit`:

```bash
gpg --edit-key 5B68574315AA1860B7C329B3B65B8EB671FAA22F
gpg --edit-key D055A0E9A9FF4D2A7517BC67F99A055334CA4E43
```

Clone the existing notes and configure this device:

```bash
gh repo clone KristianDamPedersen/org-notes ~/org -- --branch main
chmod 700 ~/org
git -C ~/org switch -c devices/laptop
git -C ~/org config org-sync.repository KristianDamPedersen/org-notes
git -C ~/org config push.default nothing
git -C ~/org config core.autocrlf false
git -C ~/org config credential.https://github.com.helper '!gh auth git-credential'
```

Install the sync hooks, which Git does not copy when cloning:

```bash
python3 - <<'PY'
import importlib.util
from pathlib import Path
source = Path('/etc/nixos/config/doom/bin/org-sync.py')
spec = importlib.util.spec_from_file_location('org_sync', source)
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)
worker.install_hooks(Path.home() / 'org')
PY
org-sync --root ~/org check-index
export GPG_TTY=$(tty)
gpg-connect-agent updatestartuptty /bye
gpg --output /dev/null --decrypt ~/org/encryption-test.org.gpg
```

Open Emacs. Open, save, and reopen an encrypted note, then run:

```text
M-x my-org-sync-mode
M-x my-org-sync-now
```

Check `*Messages*` for successful sync. Enable the mode each Emacs session unless
`(my-org-sync-mode 1)` is enabled in the configuration. Keep the `devices/laptop`
branch; do not enable automatic deletion of PR branches in the notes repository.

## 5. Google Calendar

In Emacs, evaluate with `M-:`:

```elisp
(my-google-calendar-ensure-credentials)
```

Run `M-x org-gcal-fetch`, authorize the Google account in the browser, and check
`~/org/calendar.org.gpg`. This first fetch only downloads events.

Use `SPC o s` afterward to publish local timed reservations and fetch events.
`SPC o c` opens the visual week; `SPC o w` plans the week.

## 6. Gmail
> The Gmail wrapper initializes the local Notmuch database and Lieer repository automatically on its first sync or send.
```

In Emacs, evaluate with `M-:`:

```elisp
(async-shell-command
 (concat
  (shell-quote-argument
   (expand-file-name "bin/gmail-sync.sh" doom-user-dir))
  " sync --limit 500"))
```

Wait for completion, then open mail with `SPC o m`. Send a test email to yourself
with `C-c C-c` and confirm delivery. The 500-message limit applies per sync;
it does not cap the total local mailbox.

## 7. Save the machine configuration

```bash
swapon --show
cd /etc/nixos
git add config/hardware/laptop-hardware.nix modules/hosts/laptop
git diff --cached --check
git diff --cached
git commit -m "Configure laptop hardware, disk and swap"
git push origin main
```

For later changes:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#laptop
```

Restart Emacs after rebuilding its configuration.

## 8. Woodpecker CI

The laptop runs a Woodpecker server and one local-backend agent
(`modules/features/woodpecker.nix`), published on its tailnet name
`https://asus-srv.tail0502bb.ts.net` through Tailscale Funnel. Do these steps once,
before the first rebuild that includes the feature.

1. Register a GitHub OAuth app on the personal account (Settings → Developer
   settings → OAuth Apps): homepage `https://asus-srv.tail0502bb.ts.net`, callback
   `https://asus-srv.tail0502bb.ts.net/authorize`. Keep the client ID and secret in
   1Password.
2. In the Tailscale admin console, on the DNS page, enable MagicDNS and HTTPS
   certificates. Allow Funnel in the access controls policy:

   ```json
   "nodeAttrs": [
     { "target": ["autogroup:member"], "attr": ["funnel"] }
   ]
   ```

3. Create the secrets, root-owned and mode 0600. The agent secret must match in
   both files; keep a copy in 1Password.

   ```bash
   sudo install -d -m 0700 /var/lib/woodpecker-secrets
   sudo install -m 0600 /dev/null /var/lib/woodpecker-secrets/server.env
   sudo install -m 0600 /dev/null /var/lib/woodpecker-secrets/agent.env
   secret=$(openssl rand -hex 32)
   printf 'WOODPECKER_AGENT_SECRET=%s\n' "$secret" \
     | sudo tee /var/lib/woodpecker-secrets/agent.env >/dev/null
   printf 'WOODPECKER_AGENT_SECRET=%s\nWOODPECKER_GITHUB_CLIENT=<client id>\nWOODPECKER_GITHUB_SECRET=<client secret>\n' "$secret" \
     | sudo tee /var/lib/woodpecker-secrets/server.env >/dev/null
   unset secret
   sudoedit /var/lib/woodpecker-secrets/server.env   # fill in the client ID and secret
   ```

4. Rebuild and publish the server:

   ```bash
   cd /etc/nixos && git pull
   sudo nixos-rebuild switch --flake /etc/nixos#laptop
   systemctl status woodpecker-server woodpecker-agent-local
   sudo tailscale funnel --bg 8000
   ```

5. Open `https://asus-srv.tail0502bb.ts.net` and sign in with GitHub once; that
   creates the admin user. Its access token is under User settings → CLI & API.
6. Store the access token and the repository secrets declared in
   `woodpeckerCi.repositories` (`modules/hosts/laptop/configuration.nix`) as
   root-only files. Keep the originals in 1Password.

   | File in `/var/lib/woodpecker-secrets/` | Value |
   |---|---|
   | `api-token` | the Woodpecker access token from step 5 |
   | `actify-gh-read-token` | a fine-grained GitHub token on `KristianDamPedersen/actify` with Pull requests: Read |
   | `actify-ghcr-token` | a classic GitHub token with only `write:packages` |

   ```bash
   for f in api-token actify-gh-read-token actify-ghcr-token; do
     sudo install -m 0600 /dev/null /var/lib/woodpecker-secrets/$f
     sudoedit /var/lib/woodpecker-secrets/$f
   done
   sudo systemctl start woodpecker-repositories
   journalctl -u woodpecker-repositories -b
   ```

   The service activates the declared repositories and applies their settings
   and secrets. It runs again after each rebuild that changes the declaration;
   after changing a file, start it by hand. Only declare repositories whose
   contributors you trust: pipelines run on this machine as a user in the
   `docker` group.

   Secrets can instead come from 1Password references (`reference =
   "op://vault/item/field"`), read with a service account whose token is in
   `/var/lib/woodpecker-secrets/op-service-account-token`. Service accounts
   can't read the Personal, Private or Employee vault, so the items need a vault
   of their own.

The machine keeps running with the lid closed while on mains power. Funnel
persists across reboots; `sudo tailscale funnel status` shows it, and
`sudo tailscale funnel --https=443 off` removes it.

## macOS host (`inspari-macbook`)

The MacBook uses nix-darwin. The checkout lives in `~/.dotfiles/nixos`; the
configuration links it to `/etc/nixos`.

First activation, with Nix already installed. nix-darwin refuses to replace
`/etc` files it did not create, so move the installer's copies aside first:

```bash
for f in /etc/nix/nix.conf /etc/bashrc /etc/zshrc; do
  [ -e "$f" ] && sudo mv "$f" "$f.before-nix-darwin"
done
sudo nix --extra-experimental-features 'nix-command flakes' \
  run nix-darwin/master#darwin-rebuild -- \
  switch --flake ~/.dotfiles/nixos#inspari-macbook
```

Moving `/etc/nix/nix.conf` aside also removes the installer's
`experimental-features` setting, hence the explicit flag. nix-darwin writes a
new `nix.conf` with flakes enabled.

Log out and back in so apps launched from Finder or Spotlight see the
launchd environment (kitty's `KITTY_CONFIG_DIRECTORY`).

For later changes:

```bash
sudo darwin-rebuild switch --flake /etc/nixos#inspari-macbook
```
