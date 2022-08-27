PROJECT_DIR    := $(shell pwd)
PROJECT_PARAMS := secrets/params.yaml
APPLICATION    := $(shell basename $(PROJECT_DIR))


TEMPLATE_DIR   := ./templates
TEMPLATES := $(shell find $(TEMPLATE_DIR) -name '*.yaml')

TEAM        := $(shell yq .team $(PROJECT_PARAMS))
PIPELINE    := $(APPLICATION)
REPOSITORY  := $(shell git remote get-url origin | sed -Ene's_git@(github.com):([^/]*)_https://\1/\2_p')

CI_DIR      := $(PROJECT_DIR)/ci
BRANCH      := $(shell git branch --show-current)
PRE         := SNAPSHOT
ifeq ($(PRE),SNAPSHOT)
  PRE_NO_VERSION := true
else
  PRE_NO_VRESION := false
endif

CHART_VERSION=0.1.0-SNAPSHOT
APP_VERSION=latest

Chart.lock: Chart.yaml
	@helm dependency update
lock: Chart.lock

dependencies: lock
	@helm dependency build

package: $(TEMPLATES) dependencies
	@yq -i '.version="$(CHART_VERSION)"' Chart.yaml
	@yq -i '.appVersion="$(APP_VERSION)"' Chart.yaml
	@helm package . 

.PHONY: secrets
secrets: $(PROJECT_PARAMS)
	@vault kv put concourse/$(TEAM)/$(PIPELINE)/minio \
		fqdn=$(shell yq .minio.fqdn $(PROJECT_PARAMS)) \
		access_key_id=$(shell yq .minio.access-key $(PROJECT_PARAMS)) \
		secret_access_key=$(shell yq .minio.secret-key $(PROJECT_PARAMS))
	@vault kv put concourse/$(TEAM)/$(PIPELINE)/registry \
    fqdn="$(shell yq e .registry.fqdn $(PROJECT_PARAMS))"  \
    robot='$(shell yq e .registry.robot $(PROJECT_PARAMS))'  \
    token="$(shell yq e .registry.token $(PROJECT_PARAMS))"


.PHONY: pipeline
pipeline: secrets
	@fly --target $(TEAM) set-pipeline --pipeline $(PIPELINE) --config $(CI_DIR)/pipeline/pipeline.yaml --non-interactive \
      --var application=$(APPLICATION)  --var team=$(TEAM) \
			--var repository=$(REPOSITORY) --var branch=$(BRANCH) \
      --var bump=$(BUMP) --var pre=$(PRE) --yaml-var pre-no-version=$(PRE_NO_VERSION)
	@fly --target $(TEAM) unpause-pipeline --pipeline $(PIPELINE)

