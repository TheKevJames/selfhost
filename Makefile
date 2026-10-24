HAS_PODMAN := $(if $(shell command -v podman),y,n)
UNAME_S := $(shell uname -s)
ifeq ($(HAS_PODMAN),y)
	COMPOSE := podman-compose
else
	COMPOSE := docker compose
endif

.PHONY: down ps pull restart start stop up logs logsf setup init init-git init-timers init-mdns init-backup init-photo-frame update clean

# docker compose convenience
down:
	$(COMPOSE) down
ps:
	$(COMPOSE) ps
pull:
	$(COMPOSE) pull $(SERVICE)
restart:
	$(COMPOSE) restart $(SERVICE)
start:
	$(COMPOSE) start $(SERVICE)
stop:
	$(COMPOSE) stop $(SERVICE)
up:
	$(COMPOSE) up -d --remove-orphans $(SERVICE)
logs:
	$(COMPOSE) logs $(SERVICE)
logsf:
	$(COMPOSE) logs -f --tail=30 $(SERVICE)

# misc commands
init: init-backup init-git init-timers init-mdns init-photo-frame init-logrotate
	sudo cp sys/daemon.json /etc/docker/daemon.json
	sudo install -D -m 0644 sys/docker-ssd.conf /etc/systemd/system/docker.service.d/ssd.conf
	sudo systemctl daemon-reload
	sudo systemctl restart docker

init-git:
	git config filter.qbt-strip.clean "sed -e '/^Cookies=@Invalid()[[:space:]]*$$/d' -e 's/^Session\\\\UseAlternativeGlobalSpeedLimit=.*/Session\\\\UseAlternativeGlobalSpeedLimit=false/'"
	git add --renormalize data/qbittorrent/config/qBittorrent.conf

init-timers:
	sed -e 's|@REPO@|$(CURDIR)|g' -e 's|@USER@|$(shell id -un)|g' sys/jellyfin-log-alert.service | sudo tee /etc/systemd/system/jellyfin-log-alert.service >/dev/null
	sudo cp sys/jellyfin-log-alert.timer /etc/systemd/system/jellyfin-log-alert.timer
	sudo systemctl daemon-reload
	sudo systemctl enable --now jellyfin-log-alert.timer

init-mdns:
	sudo apt install -y avahi-daemon avahi-utils
	sudo systemctl enable --now avahi-daemon
	sed -e 's|@REPO@|$(CURDIR)|g' -e 's|@USER@|$(shell id -un)|g' sys/mdns-aliases.service | sudo tee /etc/systemd/system/mdns-aliases.service >/dev/null
	sudo systemctl daemon-reload
	sudo systemctl enable --now mdns-aliases.service

init-backup:
	sudo apt install -y --no-install-recommends restic
	sudo restic self-update
	for u in backup backup-check; do \
		sed -e 's|@REPO@|$(CURDIR)|g' -e 's|@USER@|$(shell id -un)|g' sys/$$u.service | sudo tee /etc/systemd/system/$$u.service >/dev/null; \
		sudo cp sys/$$u.timer /etc/systemd/system/$$u.timer; \
	done
	sudo systemctl daemon-reload
	sudo systemctl enable --now backup.timer backup-check.timer

# Debian's rclone predates the 2025 Google Photos API changes. Upgrade via the
# upstream .deb rather than a bare binary swap: its higher package version stops
# a later Debian security update from silently reinstalling the old binary.
init-photo-frame:
	sudo apt install -y --no-install-recommends jq rclone
	sudo rclone selfupdate --package deb
	sed -e 's|@REPO@|$(CURDIR)|g' -e 's|@USER@|$(shell id -un)|g' sys/photo-frame-sync.service | sudo tee /etc/systemd/system/photo-frame-sync.service >/dev/null
	sudo cp sys/photo-frame-sync.timer /etc/systemd/system/photo-frame-sync.timer
	sudo systemctl daemon-reload
	sudo systemctl enable --now photo-frame-sync.timer

init-logrotate:
	sudo apt install -y --no-install-recommends logrotate
	sudo cp sys/logrotate.conf /etc/logrotate.conf

update:
	sudo apt update -y
	sudo apt upgrade -y
	make pull
	make up

clean:
	docker system prune -a
	docker volume prune
	sudo apt autoremove
	sudo journalctl --vaccuum-time=30d
