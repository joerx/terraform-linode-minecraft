MODULE ?= server
PACKAGE_NAME ?= $(shell basename $(CURDIR))-$(MODULE)
COMMIT ?= $(shell git rev-parse --short HEAD)
VERSION ?= v0.1.0-$(COMMIT)

PACKAGE_FILE ?= $(PACKAGE_NAME)-$(VERSION).tar.gz

.PHONY: default
default: test

out/$(PACKAGE_FILE):
	mkdir -p out
	tar -czf out/$(PACKAGE_FILE) \
		-C $(MODULE) \
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
	terraform -chdir=$(MODULE) init
	terraform -chdir=$(MODULE) test

.PHONY: check-fmt
check-fmt:
	find $(MODULE) -type f -name '*.tf' -or -name '*.tfvars' -or -name '*.tftest.hcl' | xargs -n1 terraform fmt -check -diff

release:
	gh release create $(VERSION) --title "Release $(VERSION)" --target main --generate-notes
