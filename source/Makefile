NAME	?= add-kvm-guest
VERSION	?= 0.0
PKG	?= $(NAME)_$(VERSION)_all

deb: files
	$(shell sed -i "s/BUILD_VERSION/$(VERSION)/" $(OUTPUT))
	$(eval SIZE = $(shell du -k $(OUTPUT) | sed 's/^\([0-9]\+\).*/\1/'))
	$(shell sed -i "s/INSTALL_SIZE/$(SIZE)/" $(TMPDIR)/DEBIAN/control)
	$(shell sed -i "s/INSTALL_VERSION/$(VERSION)/" $(TMPDIR)/DEBIAN/control)
	dpkg-deb --build $(TMPDIR) $(PKG).deb
	rm -rf $(TMPDIR)

files: temp
	cp -a ../DEBIAN $(TMPDIR)/
	cp -a ../config $(TMPDIR)/etc/default/$(NAME)
	cp -a $(NAME) $(OUTPUT)

temp:
	$(eval TMPDIR = $(shell mktemp -d))
	$(eval OUTPUT = $(TMPDIR)/usr/sbin/$(NAME))
	mkdir -p $(TMPDIR)/usr/sbin
	mkdir -p $(TMPDIR)/etc/default
