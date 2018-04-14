# service-manager: systemd unit generator

Generate systemd unit files from local configuration.

1. Modify `service-manager-generator` to fit your needs
2. Copy the script to `/etc/systemd/system-generator/`
3. Create `/opt/services.json` (see `services_example.json`)
4. Run `systemctl daemon-reload`
5. Run `systemctl start multi-user.target`

See [systemd.generator](https://www.freedesktop.org/software/systemd/man/systemd.generator.html)
for more info.
