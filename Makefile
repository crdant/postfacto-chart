CHART_VERSION=0.1.0-SNAPSHOT
APP_VERSION=latest

TEMPLATE_DIR   := ./templates
TEMPLATES := $(shell find $(TEMPLATE_DIR) -name '*.yaml')

lock: Chart.yaml
	@helm dependency update
Chart.lock: lock

dependencies: lock
	@helm dependency build

package: $(TEMPLATES) dependencies
	@yq -i '.version="$(CHART_VERSION)"' Chart.yaml
	@yq -i '.appVersion="$(APP_VERSION)"' Chart.yaml
	@helm package . 
