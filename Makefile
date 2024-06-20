HAS_PODMAN := $(if $(shell command -v podman),y,n)
UNAME_S := $(shell uname -s)
ifeq ($(HAS_PODMAN),y)
	COMPOSE := podman-compose
else
	COMPOSE := docker compose
endif

.PHONY: help up down ps pull
help:
	@echo "Wrapper for docker-compose usage"

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
