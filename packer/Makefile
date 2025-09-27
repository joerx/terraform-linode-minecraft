.PHONY: default
default: check-fmt clean build

.PHONY: build
build: output/qemu-ubuntu/ubuntu-jammy.img

output/qemu-ubuntu/ubuntu-jammy.img:
	PACKER_LOG=1 packer build qemu-ubuntu.pkr.hcl

.PHONY: fmt
fmt:
	packer fmt .

.PHONY: check-fmt
check-fmt:
	packer fmt -check -diff .

.PHONY: clean
clean:
	rm -rf output
