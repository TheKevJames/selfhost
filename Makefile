HAS_PODMAN := $(if $(shell command -v podman),y,n)
UNAME_S := $(shell uname -s)
ifeq ($(HAS_PODMAN),y)
	COMPOSE := podman-compose
else ifeq ($(UNAME_S),Darwin)
	COMPOSE := docker-compose-v1
else ifeq ($(UNAME_S),Linux)
	COMPOSE := docker compose
endif

ifeq ($(UNAME_S),Linux)
	COMPOSE_FLAGS := -f docker-compose.yml
endif
ifeq ($(UNAME_S),Darwin)
	COMPOSE_FLAGS := -f docker-compose.yml -f docker-compose.osx.yml
endif

.PHONY: help up down ps pull
help:
	@echo "Wrapper for docker-compose usage"

down:
	$(COMPOSE) --profile=$(shell hostname) down
ps:
	$(COMPOSE) --profile=$(shell hostname) ps
pull:
	$(COMPOSE) --profile=$(shell hostname) pull $(SERVICE)
restart:
	$(COMPOSE) --profile=$(shell hostname) restart $(SERVICE)
start:
	$(COMPOSE) --profile=$(shell hostname) start $(SERVICE)
stop:
	$(COMPOSE) --profile=$(shell hostname) stop $(SERVICE)
up:
	$(COMPOSE) --profile=$(shell hostname) up -d --remove-orphans $(SERVICE)
