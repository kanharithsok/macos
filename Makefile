# Makefile for macOS Complete System Update
# Run with: make update
#
# Environment vars:
#   YES=1         Skip all confirmation prompts (make update sets this automatically)
#   BREWFILE=...  Override Brewfile path for dump/restore

SHELL := /bin/bash

.PHONY: help update system brew mas microsoft clean status brew-list dump restore

help:
	@echo '🚀 macOS Update Commands:'
	@echo '  make update       - Complete system update (recommended)'
	@echo '  make status       - Show what needs updating'
	@echo '  make brew         - Update Homebrew packages only (no Gatekeeper popups)'
	@echo '  make system       - Update macOS only'
	@echo '  make mas          - Update App Store apps only'
	@echo '  make microsoft    - Update Microsoft apps only'
	@echo '  make brew-list    - List all installed packages'
	@echo '  make dump         - Export all installed packages to Brewfile'
	@echo '  make restore      - Install all packages from Brewfile (new machine)'
	@echo '  make clean        - Clean up and free space'
	@echo '  make help         - Show this help message'
	@echo ''
	@echo '💡 Tips:'
	@echo '  YES=1 make restore   - Skip confirmation prompt'
	@echo '  YES=1 make system    - Skip confirmation prompt'

update:
	@echo "🔄 Running full system update..."
	@echo ""
	@$(MAKE) --no-print-directory YES=1 system
	@$(MAKE) --no-print-directory brew
	@$(MAKE) --no-print-directory mas
	@$(MAKE) --no-print-directory microsoft
	@$(MAKE) --no-print-directory clean
	@echo ""
	@echo "✅ All updates completed successfully!"
	@open "raycast://extensions/raycast/raycast/confetti"

status:
	@echo "📊 Current update status:"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "🍺 HOMEBREW STATUS:"
	@FORMULAE=$$(brew leaves 2>/dev/null); CASKS=$$(brew list --casks 2>/dev/null); \
	echo "  📦 Total packages: $$(echo "$$FORMULAE" | grep -c .) explicitly installed formulae, $$(echo "$$CASKS" | grep -c .) casks"
	@echo "  ⬆️  Updates available:"
	@OUTDATED=$$(brew outdated --greedy 2>/dev/null); \
	if [ -n "$$OUTDATED" ]; then \
		echo "$$OUTDATED" | sed 's/^/    /'; \
	else \
		echo "    ✓ All Homebrew packages are up to date!"; \
	fi
	@echo ""
	@echo "📦 APP STORE STATUS:"
	@if command -v mas > /dev/null; then \
		echo "  Installed apps: $$(mas list | wc -l | tr -d ' ')"; \
		echo "  Updates available:"; \
		OUTDATED_MAS=$$(mas outdated 2>/dev/null); \
		if [ -n "$$OUTDATED_MAS" ]; then \
			echo "$$OUTDATED_MAS" | sed 's/^/    /'; \
		else \
			echo "    ✓ All App Store apps are up to date!"; \
		fi \
	else \
		echo "  ⚠️  mas-cli not installed (run: brew install mas)"; \
	fi
	@echo ""
	@echo "🖥️  MACOS STATUS:"
	@if softwareupdate --list --all 2>&1 | grep -q "No new software available"; then \
		echo "  ✓ macOS is up to date"; \
	else \
		softwareupdate --list --all | grep -v "Software Update Tool" | grep -v "Finding available software"; \
	fi

system:
	@if softwareupdate --list --all 2>&1 | grep -q "No new software available"; then \
		echo "🖥️  macOS is up to date — skipping."; \
	else \
		echo "🖥️  macOS updates available:"; \
		softwareupdate --list --all 2>&1 | grep -v "Software Update Tool" | grep -v "Finding available software"; \
		if [ "$$YES" = "1" ]; then \
			echo "🖥️  Installing macOS updates (auto-confirmed by YES=1)..."; \
			sudo softwareupdate --install --all --restart --agree-to-license; \
		else \
			read -p "Install macOS updates? (y/n) " -n 1 -r; \
			echo ""; \
			if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
				sudo softwareupdate --install --all --restart --agree-to-license; \
			else \
				echo "⏭️  Skipping macOS updates."; \
			fi; \
		fi; \
	fi

brew:
	@echo "🍺 Updating Homebrew..."
	@brew update --quiet 2>/dev/null || brew update
	@OUTDATED=$$(brew outdated --greedy 2>/dev/null); \
	if [ -n "$$OUTDATED" ]; then \
		echo "🍺 Upgrading packages with --no-quarantine (no Gatekeeper popups)..."; \
		HOMEBREW_CASK_OPTS="--no-quarantine" brew upgrade --greedy; \
	else \
		echo "🍺 All Homebrew packages are up to date!"; \
	fi
	@brew autoremove --quiet 2>/dev/null || true

mas:
	@if command -v mas > /dev/null; then \
		OUTDATED=$$(mas outdated 2>/dev/null); \
		if [ -n "$$OUTDATED" ]; then \
			echo "📦 Updating App Store apps..."; \
			mas upgrade; \
		else \
			echo "📦 App Store apps are up to date — skipping."; \
		fi; \
	else \
		echo "⚠️  mas-cli not installed. Run: brew install mas"; \
	fi

microsoft:
	@MSUPDATE_PATH="/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app/Contents/MacOS/msupdate"; \
	if [ -f "$$MSUPDATE_PATH" ]; then \
		echo "🪟 Checking Microsoft app updates..."; \
		"$$MSUPDATE_PATH" --install; \
	else \
		echo "🪟 Microsoft AutoUpdate not found — skipping."; \
	fi

brew-list:
	@LEAVES=$$(brew leaves 2>/dev/null); CASKS=$$(brew list --casks 2>/dev/null); \
		echo "🍺 Installed Homebrew Formulae (explicitly installed):"; \
		if [ -n "$$LEAVES" ]; then \
			echo "$$LEAVES" | sed 's/^/  /'; \
		else \
			echo "  None"; \
		fi; \
		echo ""; \
		echo "🖥️  Installed Casks (GUI applications):"; \
		if [ -n "$$CASKS" ]; then \
			echo "$$CASKS" | sed 's/^/  /'; \
		else \
			echo "  None"; \
		fi; \
		echo ""; \
		echo "📊 Total: $$(echo "$$LEAVES" | grep -c .) explicitly installed formulae, $$(echo "$$CASKS" | grep -c .) casks"

clean:
	@echo "🧹 Cleaning up..."
	@brew cleanup --prune=all 2>/dev/null || true
	@echo "📊 Disk space:"
	@df -h / | tail -1 | awk '{print "  Free: " $$4 " of " $$2}'

# Backup & restore for OS reinstallation
#   make dump            → export everything to Brewfile
#   make restore         → reinstall everything on a fresh machine
#   Override path: make dump BREWFILE=~/sync/Brewfile-macbook

BREWFILE ?= Brewfile

dump:
	@echo "💾 Exporting all installed software to $(BREWFILE)..."
	@brew bundle dump --file="$(BREWFILE)" --force
	@echo ""
	@echo "📊 Brewfile summary:"
	@echo "  🍺 Taps:      $$(grep -c '^tap ' "$(BREWFILE)" 2>/dev/null || echo 0)"
	@echo "  🍺 Formulae:  $$(grep -c '^brew ' "$(BREWFILE)" 2>/dev/null || echo 0)"
	@echo "  🖥️  Casks:     $$(grep -c '^cask ' "$(BREWFILE)" 2>/dev/null || echo 0)"
	@echo "  📦 MAS apps:  $$(grep -c '^mas ' "$(BREWFILE)" 2>/dev/null || echo 0)"
	@echo ""
	@echo "✅ Done! Copy $(BREWFILE) to your new machine and run: make restore"

restore:
	@echo "🔄 Restoring packages from $(BREWFILE)..."
	@if [ ! -f "$(BREWFILE)" ]; then \
		echo "❌ No $(BREWFILE) found."; \
		echo "   Copy your Brewfile from your old machine first."; \
		echo "   Or run 'make dump' there to create one."; \
		exit 1; \
	fi
	@echo "📋 Packages to install:"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@grep -v '^#' "$(BREWFILE)" | grep -v '^$$' | sed 's/^/  /'
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@if [ "$$YES" = "1" ]; then \
		echo "🍺 Installing everything from $(BREWFILE) (auto-confirmed by YES=1)..."; \
		brew bundle install --file="$(BREWFILE)" --no-lock; \
		echo "✅ All packages restored!"; \
	else \
		read -p "Install all of the above? This may take a while. (y/n) " -n 1 -r; \
		echo ""; \
		if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
			echo "🍺 Installing everything from $(BREWFILE)..."; \
			brew bundle install --file="$(BREWFILE)" --no-lock; \
			echo "✅ All packages restored!"; \
		else \
			echo "⏭️  Skipping restore."; \
		fi; \
	fi

# Individual package upgrade
upgrade-%:
	@echo "⬆️  Upgrading $(@:upgrade-%=%) with --no-quarantine..."
	@HOMEBREW_CASK_OPTS="--no-quarantine" brew upgrade --greedy $(@:upgrade-%=%) || echo "⚠️  Upgrade failed for $(@:upgrade-%=%)"
