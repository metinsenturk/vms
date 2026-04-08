.PHONY: gitignore


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
