# Author: Eric Pruitt (http://www.codevat.com)
# License: 2-Clause BSD (http://opensource.org/licenses/BSD-2-Clause)
# Description: This Makefile is designed to create a statically linked Vim
#       binary without any dependencies on the host system's version of glibc.

# Directory in which to install Vim
INSTALLDIR=$(HOME)/vim
# Folder in $PATH where symlinks to the executables are placed.
BINDIR=$(HOME)/bin
# Extension to use when creating a compressed, distributable archive.
DISTEXTENSION=tar.bz2

# URL of the Vim source code repository
REPOSITORY=https://github.com/vim/vim.git
# Basename of the compressed archive
DISTTARGET=vim.$(DISTEXTENSION)
# Determines whether or not `make` is automatically executed inside $INSTALLDIR
# to create symlinks to the executables. Can be "false" or "true" but should
# generally not be modified by the end-user and only exists to simplify
# creation of distributable archives.
DISTMAKE=true
# Variable representing dependency on the Vim source code repo. Will only be
# non-empty if the vim-src folder does not exist.
SRCDEP=$(if $(wildcard vim-src),,vim-src)

all: vim-src/src/vim

vim-src:
	git clone $(REPOSITORY) vim-src

update: $(SRCDEP)
	@set -e; \
	cd vim-src; \
	echo 'Checking for updates...'; \
	git fetch origin; \
	if ! git diff origin/master HEAD --quiet; then \
		$(MAKE) -C .. -s clean; \
		git merge origin/master; \
	else \
		echo 'No updates found.'; \
		exit 1; \
	fi

vim-src/src/auto/config.status: $(SRCDEP)
	cd vim-src && \
	LDFLAGS="-rdynamic" ./configure \
		--prefix=/dev/null/SET_THE_VIMRUNTIME_ENVIRONMENT_VARIABLE \
		--disable-channel \
		--disable-gpm \
		--disable-gtktest \
		--disable-gui \
		--disable-netbeans \
		--disable-nls \
		--disable-selinux \
		--disable-smack \
		--disable-sysmouse \
		--disable-xsmp \
		--enable-python3interp=yes \
		--with-python3-command=/opt/python3.10/bin/python3 \
		--enable-multibyte \
		--with-features=huge \
		--enable-fail-if-missing 

vim-src/src/vim: vim-src/src/auto/config.status
	cd vim-src && $(MAKE)

$(INSTALLDIR)/vim: vim-src/src/vim
	@echo 'Installing:'
	@if [ ! -e $(INSTALLDIR) ]; then \
		mkdir $(INSTALLDIR); \
	fi
	@if [ -e $(INSTALLDIR)/runtime ]; then \
		echo "- Removing existing runtime folder"; \
		rm -rf $(INSTALLDIR)/runtime; \
	fi
	@cp -f -R \
		vim-src/src/xxd/xxd \
		vim-src/src/vim \
		vim-src/runtime \
		vim.sh \
		$(INSTALLDIR)
	@cp Makefile.dist $(INSTALLDIR)/Makefile
	@echo "- $(INSTALLDIR)"
	@if $(DISTMAKE); then \
		cd $(INSTALLDIR) || exit 1; \
		$(MAKE) -s BINDIR=$(BINDIR) install; \
	fi

install: $(INSTALLDIR)/vim

$(DISTTARGET): vim-src/src/vim
	@$(MAKE) -s INSTALLDIR=$(PWD)/vim DISTMAKE=false install > /dev/null
	@tar acf $@ vim/
	@rm -rf vim/
	@echo 'Created distributable, compressed archive: $@'

dist: $(DISTTARGET)

uninstall:
	@if [ -e $(INSTALLDIR)/Makefile ]; then \
		set -e; \
		cd $(INSTALLDIR); \
		$(MAKE) -s uninstall; \
		echo '- $(INSTALLDIR)'; \
		rm -rf $(INSTALLDIR); \
	else \
		echo 'Nothing to uninstall.'; \
		exit 1; \
	fi

clean:
	@rm -v -f $(DISTTARGET) vim-src/.config.h-modified vim-src/src/*.orig
	@cd vim-src && git reset --hard && git clean -x -f -d -q

cleanest:
	rm -rf vim-src

.PHONY: clean cleanest dist install update uninstall
