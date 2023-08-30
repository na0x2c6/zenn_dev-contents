ZENN ?= node_modules/.bin/zenn

-include myconf.mk


node_modules: package.json package-lock.json
	npm ci
	touch $@

.PHONY: preview
preview: node_modules
	$(ZENN) preview
