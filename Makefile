PROJECT     := MyApp
SCHEME      := MyApp
BUNDLE_ID   := com.example.myapp

.PHONY: help validate check lint build test clean open

help: ## Affiche les cibles disponibles
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

validate: ## Structure .pbxproj/sources/assets (sans Xcode, Linux OK)
	node scripts/validate-project.mjs

check: validate ## Structure + syntaxe + type-check + tests + lint (Linux OK)
	bash scripts/swift-check.sh

lint: ## SwiftLint uniquement (brew install swiftlint)
	bash scripts/lint.sh

build: ## Compile l'app pour un simulateur (macOS requis)
	bash scripts/xcodebuild.sh build

test: ## Tests unitaires + UI (macOS requis)
	bash scripts/xcodebuild.sh test

clean: ## Nettoie les artefacts de build locaux
	rm -rf build DerivedData

open: ## Ouvre le projet dans Xcode (macOS requis)
	open $(PROJECT).xcodeproj
