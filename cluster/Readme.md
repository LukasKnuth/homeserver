# FluxCD cluster configuration

This configuration is used by FluxCD to automate _most_ of the configuration in the cluster. Sadly, due to restrictions on certain apps, a few steps must be executed manually.

## DNS PiHole

Since PiHole is used as the local DNS Server and some apps define `IngressRoutes` using local DNS entries, we need to add these entries to PiHole via the admin panel.

To reach PiHole before these are setup, add the following to your `/etc/hosts` file:

```
# temporary for domain setup pihole
<static-rpi-ip>   pihole.rpi
```

Then, access the Admin Panel in the Browser via `http://pihole.rpi`, add the DNS records under "Local DNS > DNS Records" and finally remove the line from `/etc/hosts` again.

## Backups

The automated backups use the applications built-in backup functionality. This means it's required to manually restore the backup through the UI of the Apps:

* PiHole - Some configuration is done via env variables. The rest is done in the UI via "Settings > Teleporter > Restore"
* Unifi Controller - During the setup of the controller, a backup file can be uploaded.

These backup files are located in the Restic repository and can be extracted with any system that can access the repository. This is usually easiest using Restic with Fuse.
