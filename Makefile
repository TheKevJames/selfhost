HAS_PODMAN := $(if $(shell command -v podman),y,n)
UNAME_S := $(shell uname -s)
ifeq ($(HAS_PODMAN),y)
	COMPOSE := podman-compose
else
	COMPOSE := docker compose
endif

.PHONY: down ps pull restart start stop up logs logsf init update clean

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
	$(COMPOSE) logs -f $(SERVICE)

# misc commands
init:
	sudo cp sys/daemon.json /etc/docker/daemon.json
	sudo systemctl restart docker

update:
	sudo apt update -y
	sudo apt upgrade -y
	make pull
	make up

clean:
	docker system prune -a
	docker volume prune
	sudo apt autoremove
