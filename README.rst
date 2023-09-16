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

    # podman is simplest, if available
    sudo apt install -y --no-install-recommends podman pipx
    pipx ensure-path
    pipx install podman-compose
    # ~/.config/containers/containers.conf
    # [engine]
    # cgroup_manager="cgroupfs"

    # last time I set up a Pi, Raspbian couldn't get podman setup without a lot
    # of manual go compiler toolchain boostrapping, so docker is an option if
    # you need:
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh ./get-docker.sh
    rm get-docker.sh
    sudo groupadd docker
    sudo usermod -aG docker $USER

    # on OSX, use colima for your Docker VM backend to avoid needing Docker for
    # OSX:
    https://github.com/abiosoft/colima

Once you've got a container manager, you can spin up everything defined in this
repo::

    # pre-configure any relevant secrets
    $ echo 'GOOGLE_CLIENT_ID="..."' >> secrets/google.env
    $ echo 'GOOGLE_CLIENT_SECRET="..."' >> secrets/google.env

    # TODO: generate secrets
    $ docker run --rm -it -v $PWD/cloudflared:/home/nonroot/.cloudflared cloudflare/cloudflared:latest tunnel login
    $ docker run --rm -it -v $PWD/cloudflared:/home/nonroot/.cloudflared cloudflare/cloudflared:latest tunnel create selfhost
    # modify cloudflared/config.yml with the new UUID
    # TODO: the dns stuff could be a startupcontainer of some sort? Run-once jobs?
    $ docker run --rm -it -v $PWD/cloudflared:/home/nonroot/.cloudflared cloudflare/cloudflared:latest tunnel route dns selfhost example.com
    $ docker run --rm -it -v $PWD/cloudflared:/home/nonroot/.cloudflared cloudflare/cloudflared:latest tunnel route dns selfhost foo.example.com
    $ docker run --rm -it -v $PWD/cloudflared:/home/nonroot/.cloudflared cloudflare/cloudflared:latest tunnel route dns selfhost bar.example.com

    # start images
    $ make pull
    $ make up -d

TODO: pi-hole in docker

    ## PI-HOLE
    # follow the visual prompts
    $ curl -sSL https://install.pi-hole.net | bash
    # set your admin panel password, if you enabled it
    $ echo "server.port := 8000" | sudo tee /etc/lighttpd/external.conf
    $ sudo pihole -a -p

    # verify it's working at the web portal and with:
    $ pihole status
    # verify from one of your client machines that the DNS resolver is working
    $ dig -4 @PI_IP_ADDRESS example.com

    # if not, a `sudo poweroff --reboot` after the first install can help
    # if you have issues with the above, here's some things which have helped:
    # reboot: `sudo poweroff --reboot`
    # update: `pihole -up`
    # update blocklists: `pihole -g` (sometimes these seem to be initialized
    # badly at first?)

    # now is also a great time to set up IPv6:
    # /admin/settings.php?tab=dns to toggle it on
    # get the ip with `ip -6 addr show | grep global`
    $ dig -6 @PI_IPV6_ADDRESS example.com

    # update your router/clients to start using the pihole
    # https://docs.pi-hole.net/main/post-install/
    # note that if you want fallback DNS addresses, I like Cloudflare:
    #   1.1.1.1, 1.0.0.1
    #   2606:4700:4700::1111, 2606:4700:4700::1001
    # verify that worked with
    $ dig -4 example.com | grep SERVER
    $ dig -6 example.com | grep SERVER
    # the SERVER should be using the IPv4 and IPv6 addresses you found earlier

    # upgrade and restart
    $ sudo apt upgrade -y
    $ sudo poweroff --reboot

    # setup the admin account, unless you restored from a backup
    # visit http://pi.hole:8123/


Updates
-------

To update the various components::

    sudo apt update -y
    sudo apt upgrade -y
    pipx upgrade-all

    pihole -up

    cd ~/src/experiments/selfhost
    git pull
    make pull
    make up -d

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
-----------------------

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

TODOs
-----

* use syncthing folder to hold migrateable state?
* deploy `bar assistant <https://github.com/karlomikus/bar-assistant>`_
* deploy `a recipe tracker <https://github.com/awesome-selfhosted/awesome-selfhosted#recipe-management>`_, perhaps alongside a shopping list
* deploy `an html render of my vimwiki <https://github.com/vimwiki/vimwiki#changing-wiki-syntax>`_
* deploy a webscrape notifier / task dag and migrate from github release tracker:
  * full ifttt: `huginn <https://github.com/huginn/huginn>`_
  * full ifttt: `munin <http://munin-monitoring.org/>`_
  * full ifttt: `leon <https://getleon.ai/>`_
  * only webscrape: `changedetection <https://github.com/dgtlmoon/changedetection.io>`_
  * only webscrape: `kibitzr <https://kibitzr.github.io/>`_
  * get past cloudflare: `flaresolverr <https://github.com/FlareSolverr/FlareSolverr>`_
  * or rss integration: `all github thingies have .atom feeds <https://github.com/BurntSushi/ripgrep/releases.atom>`_
* configure `voice control <https://rhasspy.readthedocs.io/en/latest/>`_
* deploy a `feed reader <https://github.com/awesome-selfhosted/awesome-selfhosted#feed-readers>`_
* backup photos from Google:
  * consider adding a tagger such as `digikam <https://www.digikam.org/>`_ to embed metadata
* configure `notifications <https://github.com/caronc/apprise>`_
* monitor:
  * `hard drives <https://github.com/AnalogJ/scrutiny>`_
  * and "everything else" via prometheus/grafana
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
* expose `fava viewer <https://beancount.github.io/fava/>`_
* mirror repos to `gitea <https://about.gitea.com/>`_:
  * check out `plugins <https://gitea.com/gitea/awesome-gitea>`_
  * also `mirror to gitlab <https://docs.gitlab.com/ee/user/project/repository/mirror/index.html>`_?
  * also mirror to sourcehut?
  * `mirroring script <https://github.com/beefsack/git-mirror>`_

.. _set up networking: https://wiki.debian.org/NetworkConfiguration
.. _Debian: https://www.debian.org/releases/stable/installmanual
.. _Raspbian OS Lite x64: https://www.raspberrypi.com/software/

