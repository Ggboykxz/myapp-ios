PROJECT     := MyApp
SCHEME      := MyApp
DESTINATION := platform=iOS Simulator,name=iPhone 16
BUNDLE_ID   := com.example.myapp

.PHONY: validate build test clean open help

help: ## Affiche les cibles disponibles
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

validate: ## Vérifie la cohérence pbxproj/sources/assets (fonctionne sans Xcode)
	node scripts/validate-project.mjs

build: ## Compile l'app pour le simulateur (macOS requis)
	xcodebuild -project $(PROJECT).xcodeproj -scheme $(SCHEME) \
		-destination '$(DESTINATION)' -configuration Debug build

test: ## Exécute les tests unitaires et UI (macOS requis)
	xcodebuild -project $(PROJECT).xcodeproj -scheme $(SCHEME) \
		-destination '$(DESTINATION)' test

clean: ## Nettoie les artefacts de build locaux
	rm -rf build DerivedData

open: ## Ouvre le projet dans Xcode (macOS requis)
	open $(PROJECT).xcodeproj
