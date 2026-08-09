HAS_PODMAN := $(if $(shell command -v podman),y,n)
UNAME_S := $(shell uname -s)
ifeq ($(HAS_PODMAN),y)
	COMPOSE := podman-compose
else
	COMPOSE := docker compose
endif

.PHONY: down ps pull restart start stop up logs logsf setup init init-git init-timers update clean

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
init: init-git init-timers
	sudo cp sys/daemon.json /etc/docker/daemon.json
	sudo systemctl restart docker

init-git:
	git config filter.qbt-strip.clean "sed -e '/^Cookies=@Invalid()[[:space:]]*$$/d' -e 's/^Session\\\\UseAlternativeGlobalSpeedLimit=.*/Session\\\\UseAlternativeGlobalSpeedLimit=false/'"
	git add --renormalize data/qbittorrent/config/qBittorrent.conf

init-timers:
	sed -e 's|@REPO@|$(CURDIR)|g' -e 's|@USER@|$(shell id -un)|g' sys/jellyfin-log-alert.service | sudo tee /etc/systemd/system/jellyfin-log-alert.service >/dev/null
	sudo cp sys/jellyfin-log-alert.timer /etc/systemd/system/jellyfin-log-alert.timer
	sudo systemctl daemon-reload
	sudo systemctl enable --now jellyfin-log-alert.timer

update:
	sudo apt update -y
	sudo apt upgrade -y
	make pull
	make up

clean:
	docker system prune -a
	docker volume prune
	sudo apt autoremove
