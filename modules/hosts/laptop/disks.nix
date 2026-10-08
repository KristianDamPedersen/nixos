{ inputs, ... }: {
    flake.nixosModules.laptopConfiguration = {
        imports = [
            inputs.disko.nixosModules.disko
        ];

        # Make the configured console keymap available during early boot.
        console.earlySetup = true;

        disko.devices.disk.main = {
            type = "disk";
            device = "/dev/disk/by-id/REPLACE_WITH_LAPTOP_DISK";

            content = {
                type = "gpt";

                partitions = {
                    bios = {
                        size = "1M";
                        type = "EF02";
                    };

                    ESP = {
                        size = "1G";
                        type = "EF00";

                        content = {
                            type = "filesystem";
                            format = "vfat";
                            mountpoint = "/boot";
                            mountOptions = [ "umask=0077" ];
                        };
                    };

                    root = {
                        # Root partition takes up the remaining space.
                        size = "100%";

                        content = {
                            type = "luks";
                            name = "cryptroot";

                            askPassword = true;
                            initrdUnlock = true;

                            extraFormatArgs = [
                                "--type" "luks2"
                                "--pbkdf" "argon2id"
                            ];

                            content = {
                                type = "filesystem";
                                format = "ext4";
                                mountpoint = "/";
                            };
                        };
                    };
                };
            };
        };
    };
}
