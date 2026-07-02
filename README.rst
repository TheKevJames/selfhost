Selfhosted Platform
===================

Building up the things I selfhost as a source-controlled project. Goal here is
to have a single source for configuring all the things -- or at least a single
place where it's all documented, when that's not possible.

Setup
-----

Install the relevant OS:

* `Raspbian OS Lite`_ (pre-configure the wifi/hostname/ssh creds/etc before
  writing the image to save effort, ``sudo raspi-config`` afterwards to
  configure locale etc)
* `Debian`_ (skip the additional packages, but `set up networking`_ and ``apt
  install openssh-server``)

Configure your ssh keys (``ssh-copy-id $hostname``) and modify
``/etc/ssh/sshd_config`` how you'd like (``PermitRootLogin no`` and
``PasswordAuthentication no`` and pretty good improvements to the defaults).

From there, reboot, ssh into the new machine, and::

    sudo apt update -y
    sudo apt install -y --no-install-recommends git
    ssh-keygen -o -a 100 -t ed25519 -C "KevinJames@thekev.in" -f ~/.ssh/id_ed25519
    git clone git@github.com:TheKevJames/selfhost ~/src/personal/selfhost
    cd ~/src/personal/selfhost

After this point, further steps depend on what functions this machine will
provide. First off, you probably want to mount `External Drives`_.

Once that's done, consider increasing your swap size and/or moving it onto one
of those drives. This is especially important for low-memory systems or cases
where your default swapfile lives on an SD card::

    sudo apt update -y
    sudo apt install -y --no-install-recommends dphys-swapfile

    sudo dphys-swapfile swapoff
    sudo vi /etc/dphys-swapfile
    # CONF_SWAPFILE=/mnt/1tb/swap
    # CONF_SWAPFACTOR=2
    sudo mv /var/swap /mnt/1tb/swap

    sudo dphys-swapfile setup
    sudo dphys-swapfile swapon
    sudo poweroff --reboot

Now, install your container manager::

    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh ./get-docker.sh
    rm get-docker.sh
    sudo groupadd docker
    sudo usermod -aG docker $USER  # then logout / login

    # on OSX, use colima for your Docker VM backend to avoid needing Docker for
    # OSX:
    https://github.com/abiosoft/colima

Once you've got a container manager, you can spin up everything defined in this
repo::

    # pre-configure any relevant secrets
    $ echo 'GOOGLE_CLIENT_ID="..."' >> secrets/google.env
    $ echo 'GOOGLE_CLIENT_SECRET="..."' >> secrets/google.env

    # metrics: credentials for the exporters/collectors that feed netdata
    # (see "Metrics" below for how each token is routed)
    $ echo 'JELLYFIN_TOKEN="..."'      >> secrets/jellyfin.env       # Jellyfin API key
    $ cat >> secrets/qbittorrent.env <<'EOF'                        # WebUI login (avoids a plaintext API key in qBittorrent.conf)
    QBITTORRENT_USERNAME=...
    QBITTORRENT_PASSWORD=...
    EOF
    $ cat >> secrets/scraparr.env <<'EOF'
    BAZARR_API_KEY=...
    PROWLARR_API_KEY=...
    RADARR_API_KEY=...
    SONARR_API_KEY=...
    EOF
    $ printf '%s' '...' > secrets/syncthing_metrics_token          # Syncthing GUI API key
    # Pi-hole uses netdata's native collector; its config carries the password
    # so it is gitignored -- create it from the committed example:
    $ cp config/netdata/go.d/pihole.conf.example config/netdata/go.d/pihole.conf
    $ $EDITOR config/netdata/go.d/pihole.conf   # set the Pi-hole web password

    $ docker run --rm -it -v $PWD/data/cloudflared:/home/nonroot/.cloudflared cloudflare/cloudflared:latest tunnel login
    $ docker run --rm -it -v $PWD/data/cloudflared:/home/nonroot/.cloudflared cloudflare/cloudflared:latest tunnel create selfhost
    # modify data/cloudflared/config.yml with the new UUID
    $ bin/cloudflare-expose example.com
    $ bin/cloudflare-expose foo.example.com
    $ bin/cloudflare-expose bar.example.com

    # configure docker
    $ make init

    # start images
    $ make pull
    $ make up

Persistence is organized into three locations, which keeps backup and restore
simple:

* ``config/`` -- hand-authored, git-tracked configuration; restored by cloning
  this repo. A few app-managed config files that apps store alongside their
  runtime state instead live under ``data/`` but stay git-tracked in place.
* ``data/`` -- all runtime state (databases, indexes, tunnel credentials). This
  is the single directory to back up; rsync it to your backup target::

      rsync -aHAX --delete data/ backup-host:/backups/selfhost/data/

* ``secrets/`` -- env-file credentials, backed up on a separate (encrypted)
  channel::

      rsync -aHAX --delete secrets/ encrypted-host:/backups/selfhost/secrets/

To migrate onto a new machine (or restore from backup), stop the stack on the
old host, then clone this repo and pull the state back down (before you ``make
up``)::

    rsync -aP oldhost:~/src/personal/selfhost/data/    data/
    rsync -aP oldhost:~/src/personal/selfhost/secrets/ secrets/

Because ``data/`` already contains the cloudflared tunnel credentials, a
restore does not need the ``tunnel login`` / ``tunnel create`` steps above --
those are only for standing up a brand-new tunnel.

If you migrated Jellyfin, you may need to force it to re-init by modifying
``data/jellyfin/system.xml`` to have::

    <IsStartupWizardCompleted>false</IsStartupWizardCompleted>

There are also some manual steps which you may want to do included below.

* syncthing: visit the web UI and share any folders
* pihole: ``docker logs pihole | grep random`` to get your password

You may also want to set up NTP. This is especially necessary if this machine
will be handling any auth, as handshakes will fail if your clock drifts too far
out of sync::

    sudo apt install ntp

Syncthing
~~~~~~~~~

Visit ``:8384`` and set up any relevant shares.

Pi-Hole
~~~~~~~

::

    # grab your admin password, configure settings in the web ui
    docker logs pihole | grep random

    # verify it works
    dig -4 @NODEIPv4 example.com
    # NODEIPv6=$( ip -6 addr show | awk '/global/ {print $2}'
    dig -4 @NODEIPv6 example.com

    # make your router/hosts/etc use pihole dns
    # https://docs.pi-hole.net/main/post-install/
    # note that if you want fallback DNS addresses, I like Cloudflare:
    #   1.1.1.1, 1.0.0.1
    #   2606:4700:4700::1111, 2606:4700:4700::1001
    # verify it's configured:
    dig -4 example.com | grep SERVER
    dig -6 example.com | grep SERVER
    # the SERVER should be using the IPv4 and IPv6 addresses you found earlier

Metrics
~~~~~~~

All metrics funnel into netdata. netdata scrapes Prometheus endpoints via its
built-in go.d ``prometheus`` collector (``config/netdata/go.d/prometheus.conf``),
reaching each target by container name on the default compose network. Apps that
do not speak Prometheus natively get a small sidecar exporter:

* **jellyfin** -- ``jellyfin-exporter`` (rebelcore) on ``:9594``; needs a
  Jellyfin API key in ``secrets/jellyfin.env``.
* **prowlarr / radarr / sonarr / bazarr** -- one ``scraparr`` container on
  ``:7100`` exports the whole \*arr suite; API keys in ``secrets/scraparr.env``.
* **qbittorrent** -- ``qbittorrent-exporter`` (martabal) on ``:8090``. Auth uses
  the WebUI username/password (``secrets/qbittorrent.env``) rather than a
  generated API key, so no plaintext token is written into the tracked
  ``qBittorrent.conf``; the compose file sets ``QBITTORRENT_COOKIE_NAME`` to the
  5.2+ session cookie ``QBT_SID_<WebUI-port>``.
* **syncthing** -- exposes ``/metrics`` natively on ``:8384``; netdata scrapes
  it with the Syncthing API key supplied as a bearer token via the
  ``syncthing_metrics_token`` docker secret.
* **pihole** -- uses netdata's native ``pihole`` collector (Pi-hole API v6), not
  a sidecar. Its config lives at ``config/netdata/go.d/pihole.conf`` and is
  gitignored because it holds the Pi-hole password.

The netdata dashboard (``:19999``) shows each job under *Nodes -> go.d /
prometheus*; ``docker logs netdata`` surfaces any job that fails to scrape.

Updates
-------

To update the various components::

    cd ~/src/experiments/selfhost
    git pull
    make update

External Drives
---------------

Machines generally either mount external drives physically and expose them via
Samba, or mount them via Samba.

Physical Mounts
~~~~~~~~~~~~~~~

Quick walkthrough of how to fstab some external drives into being auto-mounted::

    # find the drives
    $ lsblk -f
    NAME        FSTYPE FSVER LABEL  UUID                                 FSAVAIL FSUSE% MOUNTPOINT
    sda
    `-sda1      ext4   1.0          43162a5a-f1b2-441f-9d51-433bea2e113c
    sdb
    `-sdb1      ext4   1.0          b9479cb5-b306-430b-998d-3d793aadfde6

    # set up the mount points
    $ sudo mkdir /mnt/1tb /mnt/4tb

    # auto-mount 'em at startup
    $ echo "UUID=43162a5a-f1b2-441f-9d51-433bea2e113c /mnt/4tb  ext4  defaults,noatime  0 0" | sudo tee -a /etc/fstab
    $ echo "UUID=b9479cb5-b306-430b-998d-3d793aadfde6 /mnt/1tb  ext4  defaults,noatime  0 0" | sudo tee -a /etc/fstab
    $ sudo systemctl daemon-reolad

    # mount 'em now
    $ sudo mount -a

Exposing Mounts via Samba
~~~~~~~~~~~~~~~~~~~~~~~~~

::

    sudo apt update -y
    sudo apt install -y --no-install-recommends samba samba-common-bin

    # configure drives
    # $ sudo vi /etc/samba/smb.conf
    # # For a readonly drive:
    # [pi-1tb]
    #   path = /mnt/1tb
    #   browseable = yes
    #   writeable = no
    #   guest ok = yes
    # # Or, to allow writes:
    # [pi-4tb]
    #   path = /mnt/4tb
    #   browseable = yes
    #   writeable = yes
    #   guest ok = yes
    #   public = yes
    #   create mask = 6444
    #   directory mask = 0755
    #   force user = pi
    #   force group = pi

    # create a samba user
    # eg. username is "pi"
    sudo smbpasswd -a pi

    # restart samba
    sudo systemctl restart smbd

Connect to Samba Shares
~~~~~~~~~~~~~~~~~~~~~~~

To mount samba shares on OSX clients, note that the permissions the server
grants and the permissions OSX *thinks* it has don't tend to stay in sync very
well. The best thing I've found to deal with this so far is to force OSX to
think it has 0777 -- it won't, the real permissions will be controlled by the
samba settings above as they are for all other clients, but at least OSX won't
get in the way.

::

    # ./bin/osx-samba-mount HOSTNAME MOUNTNAME
    ./bin/osx-samba-mount pi-1 pi-1tb
    ./bin/osx-samba-mount pi-1 pi-4tb

To connect on Windows, use File Explorer, right-click "This PC" and "Add a
Network Drive". Then input "\\IP.ADDR\SHARE_NAME". You may need to input the
credentials: "guest:".

TODOs
-----

* backup ``./data`` to a syncthing folder (maybe ``backup``?)
  * backup ``./secrets`` as well?
* deploy `bar assistant <https://github.com/karlomikus/bar-assistant>`_
* deploy `a recipe tracker <https://github.com/awesome-selfhosted/awesome-selfhosted#recipe-management>`_, perhaps alongside a shopping list
* deploy `an html render of my vimwiki <https://github.com/vimwiki/vimwiki#changing-wiki-syntax>`_
* configure `voice control <https://rhasspy.readthedocs.io/en/latest/>`_
* deploy a `feed reader <https://github.com/awesome-selfhosted/awesome-selfhosted#feed-readers>`_
* monitor cloud storage limits (dropbox, google, anything else?)
* manage `music <https://lidarr.audio/>`_
* optimize `transcoding of tv shows and movies <https://home.tdarr.io/>`_
* selfhost `location sharing <https://github.com/bilde2910/Hauk>`_
* investigate `openhab hub as new aio dashboard <https://www.openhab.org/>`_
* set up `chatbot <https://errbot.readthedocs.io/en/latest/>`_
* selfhost `calendars and contacts <https://github.com/awesome-selfhosted/awesome-selfhosted#calendar--contacts---caldav-or-carddav-servers>`_, backup from Google
* host calendar scheduling:
  * `cal.com <https://cal.com/>`_
  * `easyappointments <https://github.com/alextselegidis/easyappointments>`_
* backup my bookmarks:
  * `various options <https://github.com/awesome-selfhosted/awesome-selfhosted#bookmarks-and-link-sharing>`_
  * `lnks <https://github.com/hamvocke/lnks>`_
  * `sync from firefox <https://floccus.org/>`_
* mirror repos to `gitea <https://about.gitea.com/>`_:
  * check out `plugins <https://gitea.com/gitea/awesome-gitea>`_
  * also `mirror to gitlab <https://docs.gitlab.com/ee/user/project/repository/mirror/index.html>`_?
  * also mirror to sourcehut?
  * `mirroring script <https://github.com/beefsack/git-mirror>`_
  * or maybe use `forgejo <https://forgejo.org/>`_ and `mirror this way <https://forgejo.org/docs/latest/user/repo-mirror/>`_
* create jellyfin playlists for shows/movies with non-standard viewing orders, eg. `babylon 5 <https://www.b5tv.com/threads/jms-viewing-order.11675/>`_, `bsg <https://torrentday.cool/details.php?id=2272345>`_, `stargate <https://www.gateworld.net/news/2021/04/stargate-watch-order-three-ways-enjoy-entire-franchise/>`_
* consider pihole -> technitium

.. _set up networking: https://wiki.debian.org/NetworkConfiguration
.. _Debian: https://www.debian.org/releases/stable/installmanual
.. _Raspbian OS Lite x64: https://www.raspberrypi.com/software/
