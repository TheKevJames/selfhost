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
	$(COMPOSE) $(COMPOSE_FLAGS) down
ps:
	$(COMPOSE) $(COMPOSE_FLAGS) ps
pull:
	$(COMPOSE) $(COMPOSE_FLAGS) pull $(SERVICE)
restart:
	$(COMPOSE) $(COMPOSE_FLAGS) restart $(SERVICE)
start:
	$(COMPOSE) $(COMPOSE_FLAGS) start $(SERVICE)
stop:
	$(COMPOSE) $(COMPOSE_FLAGS) stop $(SERVICE)
up:
	$(COMPOSE) $(COMPOSE_FLAGS) up $(SERVICE)
