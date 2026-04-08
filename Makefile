.PHONY: check-tools gitignore

# Verify required CLI tools are available
check-tools:
	@echo "Checking required tools..."
	@command -v vagrant >/dev/null 2>&1 && echo "✓ vagrant found" || echo "✗ vagrant NOT found"
	@command -v ansible >/dev/null 2>&1 && echo "✓ ansible found" || echo "✗ ansible NOT found"
	@command -v ansible-playbook >/dev/null 2>&1 && echo "✓ ansible-playbook found" || echo "✗ ansible-playbook NOT found"


# Download Python .gitignore from GitHub
gitignore:
	@if [ -f .gitignore ]; then \
		echo "⚠️  .gitignore already exists, skipping"; \
	else \
		( \
			echo "📥 Downloading Python .gitignore from GitHub..."; \
			curl -fsSL https://raw.githubusercontent.com/github/gitignore/main/Python.gitignore -o .gitignore; \
			echo "✅ .gitignore created"; \
		) > /tmp/gitignore.log 2>&1; \
		echo "✓ .gitignore download complete (log: /tmp/gitignore.log)"; \
	fi
