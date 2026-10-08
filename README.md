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

```bash
export NOTMUCH_CONFIG=/etc/notmuch-config
gmail-init
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
