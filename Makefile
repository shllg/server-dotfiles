SHELL := /bin/bash
TARGET ?= $(HOME)

# All package directory names under stow/
PACKAGES := $(shell find stow -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

# -- Colors --------------------------------------------------------------------
C := \033[0;36m
G := \033[0;32m
Y := \033[1;33m
R := \033[0m

# -- Helpers -------------------------------------------------------------------
define run_notes
	@if [ -f "stow/$(1)/notes.sh" ]; then \
		echo -e "$(Y)Running notes.sh for $(1)...$(R)"; \
		bash stow/$(1)/notes.sh; \
	fi
endef

define require_pkg
	@if [ ! -d "stow/$(1)" ]; then \
		echo -e "$(Y)Error: package '$(1)' not found$(R)"; \
		echo "Run 'make list' to see available packages"; \
		exit 1; \
	fi
endef

# -- Targets -------------------------------------------------------------------
.PHONY: help
help:
	@echo "Dotfiles Stow Manager"
	@echo ""
	@echo "  make stow [PACKAGE=name]    Install a package (interactive if no PACKAGE)"
	@echo "  make unstow [PACKAGE=name]  Remove a package"
	@echo "  make restow [PACKAGE=name]  Reinstall a package (unstow + stow)"
	@echo "  make stow-all               Install all packages"
	@echo "  make unstow-all             Remove all packages"
	@echo "  make list                   List available packages"
	@echo "  make clean-links            Remove broken symlinks from $(TARGET)"
	@echo ""
	@echo "Shorthand:  make stow-tmux  /  make unstow-git  /  make restow-zsh"

.PHONY: list
list:
	@echo "Available packages:"
	@for pkg in $(PACKAGES); do \
		note=""; [ -f "stow/$$pkg/notes.sh" ] && note=" (has notes.sh)"; \
		echo "  - $$pkg$$note"; \
	done

# -- Interactive picker (pure shell, runs at recipe time) ----------------------
define pick_and_run
	@pkgs=($(PACKAGES)); \
	if command -v fzf >/dev/null 2>&1; then \
		pkg=$$(printf '%s\n' "$${pkgs[@]}" | fzf --height=40% --reverse --header="$(2)" --prompt="Package: "); \
	else \
		printf '%s\n' "$${pkgs[@]}" | cat -n; \
		read -rp "Enter number: " n; \
		pkg=$$(printf '%s\n' "$${pkgs[@]}" | sed -n "$${n}p"); \
	fi; \
	if [ -n "$$pkg" ]; then \
		$(MAKE) --no-print-directory $(1) PACKAGE=$$pkg; \
	fi
endef

# -- Stow ----------------------------------------------------------------------
.PHONY: stow
stow:
ifdef PACKAGE
	$(call require_pkg,$(PACKAGE))
	$(call run_notes,$(PACKAGE))
	@echo -e "$(C)Stowing $(PACKAGE)...$(R)"
	@cd stow && stow --no-folding -t $(TARGET) -v $(PACKAGE)
	@echo -e "$(G)Done: $(PACKAGE)$(R)"
else
	$(call pick_and_run,stow,Select package to stow)
endif

.PHONY: stow-all
stow-all:
	@for pkg in $(PACKAGES); do \
		$(MAKE) --no-print-directory stow PACKAGE=$$pkg; \
	done

# -- Unstow --------------------------------------------------------------------
.PHONY: unstow
unstow:
ifdef PACKAGE
	$(call require_pkg,$(PACKAGE))
	@echo -e "$(C)Unstowing $(PACKAGE)...$(R)"
	@cd stow && stow --no-folding -D -t $(TARGET) -v $(PACKAGE)
	@echo -e "$(G)Done: $(PACKAGE) removed$(R)"
else
	$(call pick_and_run,unstow,Select package to unstow)
endif

.PHONY: unstow-all
unstow-all:
	@for pkg in $(PACKAGES); do \
		$(MAKE) --no-print-directory unstow PACKAGE=$$pkg; \
	done

# -- Restow --------------------------------------------------------------------
.PHONY: restow
restow:
ifdef PACKAGE
	$(call require_pkg,$(PACKAGE))
	$(call run_notes,$(PACKAGE))
	@echo -e "$(C)Restowing $(PACKAGE)...$(R)"
	@cd stow && stow --no-folding -R -t $(TARGET) -v $(PACKAGE)
	@echo -e "$(G)Done: $(PACKAGE) restowed$(R)"
else
	$(call pick_and_run,restow,Select package to restow)
endif

.PHONY: restow-all
restow-all:
	@for pkg in $(PACKAGES); do \
		$(MAKE) --no-print-directory restow PACKAGE=$$pkg; \
	done

# -- Shorthand: make stow-tmux / unstow-git / restow-zsh ----------------------
stow-%:   ; @$(MAKE) --no-print-directory stow   PACKAGE=$*
unstow-%: ; @$(MAKE) --no-print-directory unstow  PACKAGE=$*
restow-%: ; @$(MAKE) --no-print-directory restow  PACKAGE=$*

# -- Install scripts to /usr/local/bin -----------------------------------------
.PHONY: install-scripts
install-scripts:
	@echo -e "$(C)Installing scripts to /usr/local/bin...$(R)"
	@for script in notify-discord check-disk notify-login; do \
		src="scripts/$${script}.sh"; \
		if [ -f "$$src" ]; then \
			cp "$$src" "/usr/local/bin/$$script"; \
			chmod 0755 "/usr/local/bin/$$script"; \
			echo -e "$(G)  $$script$(R)"; \
		fi; \
	done
	@echo -e "$(G)Done$(R)"

# -- Maintenance ---------------------------------------------------------------
.PHONY: clean-links
clean-links:
	@echo "Cleaning broken symlinks in $(TARGET)..."
	@find $(TARGET) -maxdepth 3 -type l ! -exec test -e {} \; -print -delete 2>/dev/null || true
	@echo -e "$(G)Done$(R)"
