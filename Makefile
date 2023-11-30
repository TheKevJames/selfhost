HAS_PODMAN := $(if $(shell command -v podman),y,n)
UNAME_S := $(shell uname -s)
ifeq ($(HAS_PODMAN),y)
	COMPOSE := podman-compose
else
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
	$(COMPOSE) $(COMPOSE_FLAGS) --profile=$(shell hostname) down
ps:
	$(COMPOSE) $(COMPOSE_FLAGS) --profile=$(shell hostname) ps
pull:
	$(COMPOSE) $(COMPOSE_FLAGS) --profile=$(shell hostname) pull $(SERVICE)
restart:
	$(COMPOSE) $(COMPOSE_FLAGS) --profile=$(shell hostname) restart $(SERVICE)
start:
	$(COMPOSE) $(COMPOSE_FLAGS) --profile=$(shell hostname) start $(SERVICE)
stop:
	$(COMPOSE) $(COMPOSE_FLAGS) --profile=$(shell hostname) stop $(SERVICE)
up:
	$(COMPOSE) $(COMPOSE_FLAGS) --profile=$(shell hostname) up -d --remove-orphans $(SERVICE)
