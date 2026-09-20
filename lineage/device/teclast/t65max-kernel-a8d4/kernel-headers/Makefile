.PHONY: headers_install

headers_install:
	@test -n "$(O)"
	@mkdir -p "$(O)"
	@gzip -dc "$(CURDIR)/kernel-uapi-headers.tar.gz" | tar -xf - -C "$(O)"
