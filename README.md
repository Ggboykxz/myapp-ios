# MyApp — projet SwiftUI (iOS 17.0)

Projet iOS natif **SwiftUI**, prêt à ouvrir sur Mac. Le développement se fait
sur macOS (Xcode) ; cette machine (Linux) sert à écrire le code et à valider
la structure du projet.

| | |
|---|---|
| Framework | SwiftUI + Observation (`@Observable`) |
| Cible | iOS 17.0 minimum |
| Bundle ID | `com.example.myapp` |
| Langage | Swift 5 (mode classique, pas de Swift 6 strict) |
| Architecture | MVVM — Vue / ViewModel / Model / Store |
| Tests | XCTest unitaires + XCUITest |

## État de l'environnement

Cette machine est **Linux (Firebase Studio)** : pas de Xcode, pas de
`swiftc`, pas de simulateur iOS. Un build iOS natif y est **impossible**.
Ce qui est faisable ici, et qui est en place :

- écriture et review du code Swift, structure MVVM complète ;
- `npm run validate` (ou `node scripts/validate-project.mjs`) — vérifie sans
  Xcode que le `.pbxproj`, les assets et les sources restent cohérents :
  syntaxe plist analysée par un parseur réel, IDs 24 caractères, fichiers
  orphelins ou manquants, JSON d'assets, schéma partagé ;
- CI GitHub Actions : job `validate` sur Ubuntu + job `build-and-test` sur
  runner `macos-15` (`.github/workflows/ios.yml`).

Sur Mac, il faut : **Xcode 15 ou +**, un compte Apple Developer (gratuit
suffit pour le simulateur).

## Démarrage (Mac)

```bash
open MyApp.xcodeproj     # ou `make open`
# puis ⌘R pour lancer, ⌘U pour les tests
```

En ligne de commande :

```bash
npm run validate   # ici, sans Xcode (Linux/CI) — équivalent de `make validate`
make build         # xcodebuild … build   (simulateur, macOS)
make test          # xcodebuild … test    (unitaires + UI, macOS)
```

Le `Makefile` suppose `make` (installé avec les Xcode Command Line Tools) :
sous cette machine il n'est pas présent, d'où la commande `npm run validate`.

> Le simulateur `iPhone 16` du Makefile est un exemple : liste ce qui existe
> chez toi avec `xcrun simctl list devices available` et ajuste
> `DESTINATION`.

## Arborescence

```
.
├── MyApp.xcodeproj/          # projet Xcode (schéma partagé compris)
│   └── xcshareddata/xcschemes/MyApp.xcscheme
├── MyApp/
│   ├── MyAppApp.swift        # point d'entrée, injection du ViewModel
│   ├── Views/                # SwiftUI : ContentView, ItemRow, ItemDetailView, NewItemSheet
│   ├── ViewModels/           # ItemListViewModel (@Observable, testable sans UI)
│   ├── Models/               # Item (Codable, Hashable)
│   ├── Services/             # ItemStore (protocole) + InMemory / JSONFile
│   ├── Support/              # Theme (constantes visuelles)
│   ├── Assets.xcassets/      # AppIcon + AccentColor
│   └── Preview Content/      # assets réservés aux previews
├── MyAppTests/               # tests unitaires du ViewModel
├── MyAppUITests/             # scénarios XCUITest
├── project.yml               # définition XcodeGen (fallback, optionnel)
├── scripts/validate-project.mjs
├── package.json              # `npm run validate`
├── Makefile                  # build/test macOS
├── .github/workflows/ios.yml # CI : validation + build/test sur macOS
├── .swiftlint.yml            # à activer avec brew install swiftlint
└── .editorconfig
```

## Fonctionnement

`ItemListViewModel` expose un état observable (`items`, `filter`,
`searchText`, `loadState`) et reçoit les intentions (`load`, `addItem`,
`toggle`, `delete`). Les vues lisent l'état via
`@Environment(ItemListViewModel.self)` et passent par `Bindable` pour les
liens (`$model.filter`, `$model.searchText`).

La persistance passe par le protocole `ItemStore` :

- `InMemoryItemStore` — previews et tests ;
- `JSONFileItemStore` — fichier `items.json` dans Application Support,
  encodage ISO-8601, écriture atomique.

Ajouter un écran : créer le fichier dans `MyApp/Views/`, **puis l'ajouter à la
cible** (clic droit sur le groupe → *Add Files to "MyApp"*). Vérifier ensuite
avec `npm run validate` : un fichier absent du `.pbxproj` y serait signalé.

## Renommer l'app

1. `PRODUCT_BUNDLE_IDENTIFIER` (2 occurrences : app + tests) dans le pbxproj.
2. `name:` et `targets:` dans `project.yml` (si XcodeGen est utilisé).
3. Schéma : clic sur le schéma → *Edit Scheme* → renommer.
4. `navigationTitle("MyApp")` dans `ContentView.swift`.
5. Cible `MyAppTests` : garder `@testable import MyApp` aligné sur le module.

## Options

- **XcodeGen** (régénérer le projet au lieu d'éditer le pbxproj) :
  `brew install xcodegen && xcodegen generate`.
- **SwiftLint** : `brew install swiftlint` — la config est déjà en place.
- **App icon** : déposer `AppIcon.png` (1024×1024) dans
  `MyApp/Assets.xcassets/AppIcon.appiconset/` et ajouter le champ
  `"filename"` dans son `Contents.json` (l'absence d'icône n'empêche pas de
  builder, Xcode émet simplement un avertissement).

## Limites connues de cette machine

- Pas de toolchain Swift : **aucune vérification de typage** ici, seule la
  structure est validée. Les erreurs de compilation apparaîtront à la
  première ouverture sous Xcode.
- Pas de signature de code : `CODE_SIGN_STYLE = Automatic`, `DEVELOPMENT_TEAM`
  non renseigné → à compléter dans *Signing & Capabilities* avant de déployer
  sur un appareil physique.
- `com.example.myapp` est un identifiant fictif : à remplacer avant tout
  dépôt sur l'App Store.
