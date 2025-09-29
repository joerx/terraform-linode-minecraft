PACKAGE_NAME ?= $(shell basename $(CURDIR))-server
COMMIT ?= $(shell git rev-parse --short HEAD)
VERSION ?= v0.1.0-$(COMMIT)

PACKAGE_FILE ?= $(PACKAGE_NAME)-$(VERSION).tar.gz

.PHONY: default
default: test

out/$(PACKAGE_FILE):
	mkdir -p out
	tar -czf out/$(PACKAGE_FILE) \
		-C server \
		--exclude out \
		--exclude Makefile \
		--exclude .terraform \
		--exclude '.git*' \
		--exclude tests \
		.

.PHONY: package
package: out/$(PACKAGE_FILE)

.PHONY: publish
publish: out/$(PACKAGE_FILE)
	curl \
		-H "Authorization: Bearer $(GITHUB_TOKEN)" \
		-H "Content-Type: application/gzip" \
		--data-binary @out/$(PACKAGE_FILE) \
		$(UPLOAD_URL)?name=$(PACKAGE_NAME).tar.gz

.PHONY: clean
clean:
	rm -rf out

.PHONY: test
test:
	terraform -chdir=server init -upgrade
	terraform -chdir=server test

.PHONY: check-fmt
check-fmt:
	cd server && terraform fmt -check -diff .
	cd example && terraform fmt -check -diff .

.PHONY: fmt
fmt:
	cd server && terraform fmt .
	cd example && terraform fmt .

.PHONY: release
release:
	gh release create $(VERSION) --title "Release $(VERSION)" --target main --generate-notes
