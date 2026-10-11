#!/usr/bin/env node
/**
 * Valide la cohérence du projet Xcode sans Xcode.
 *
 * Utile sur Linux/CI : on ne peut pas compiler Swift ici, mais on peut
 * vérifier que le .pbxproj, les assets et les sources restent cohérents.
 *
 * Usage : node scripts/validate-project.mjs   (ou `make validate`)
 */

import { readFileSync, readdirSync, existsSync, statSync } from "node:fs";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const errors = [];
const warnings = [];

const check = (condition, message) => {
  if (!condition) errors.push(message);
};

/** Liste récursive des fichiers et des dossiers (hors .git). */
function walk(dir, files = [], dirs = []) {
  for (const entry of readdirSync(dir)) {
    if (entry === ".git") continue;
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) {
      dirs.push(full);
      walk(full, files, dirs);
    } else {
      files.push(full);
    }
  }
  return { files, dirs };
}

const { files: allFiles, dirs: allDirs } = walk(root);
const entryNames = new Set(
  [...allFiles, ...allDirs].map((p) => p.split("/").pop())
);
const swiftFiles = allFiles.filter((f) => f.endsWith(".swift"));
const relative = (f) => f.slice(root.length + 1);

// ---------------------------------------------------------------------------
// 1. .pbxproj : structure et IDs
// ---------------------------------------------------------------------------

const pbxPath = join(root, "MyApp.xcodeproj", "project.pbxproj");
check(existsSync(pbxPath), "MyApp.xcodeproj/project.pbxproj introuvable");
const pbx = existsSync(pbxPath) ? readFileSync(pbxPath, "utf8") : "";

let depth = 0;
let negative = false;
for (const char of pbx) {
  if (char === "{") depth += 1;
  else if (char === "}") depth -= 1;
  if (depth < 0) negative = true;
}
check(depth === 0 && !negative, `pbxproj : accolades non équilibrées (delta final ${depth})`);

const idTokens = pbx.match(/FEED[0-9A-F]+/g) ?? [];
const malformedIds = [...new Set(idTokens.filter((id) => id.length !== 24))];
check(
  malformedIds.length === 0,
  `pbxproj : identifiants hors norme (24 caractères attendus) -> ${malformedIds.join(", ")}`
);

const definedIds = new Set();
for (const match of pbx.matchAll(/^\s*([0-9A-F]{24})(?: \/\*[^\n]*?\*\/)? = \{/gm)) {
  definedIds.add(match[1]);
}

const referencedIds = [...new Set(idTokens)];
const undefinedIds = referencedIds.filter((id) => !definedIds.has(id));
check(
  undefinedIds.length === 0,
  `pbxproj : références sans objet défini -> ${undefinedIds.join(", ")}`
);

// ---------------------------------------------------------------------------
// 2. Syntaxe : parseur OpenStep-plist minimal (ce que Xcode lit)
// ---------------------------------------------------------------------------

const KNOWN_ISA = new Set([
  "PBXBuildFile",
  "PBXContainerItemProxy",
  "PBXFileReference",
  "PBXFrameworksBuildPhase",
  "PBXGroup",
  "PBXNativeTarget",
  "PBXProject",
  "PBXResourcesBuildPhase",
  "PBXSourcesBuildPhase",
  "PBXTargetDependency",
  "XCBuildConfiguration",
  "XCConfigurationList",
]);

function parseOpenStep(text) {
  let i = 0;

  const fail = (message) => {
    const line = text.slice(0, i).split("\n").length;
    throw new Error(`${message} (ligne ${line})`);
  };

  const skip = () => {
    while (i < text.length) {
      const char = text[i];
      const next = text[i + 1];
      if (char === "/" && next === "*") {
        const end = text.indexOf("*/", i + 2);
        if (end === -1) fail("commentaire /* non fermé");
        i = end + 2;
      } else if (char === "/" && next === "/") {
        const end = text.indexOf("\n", i);
        i = end === -1 ? text.length : end;
      } else if (/\s/.test(char)) {
        i += 1;
      } else {
        return;
      }
    }
  };

  const parseBare = () => {
    const start = i;
    while (i < text.length && !/[\s{}()<>;,="]/.test(text[i])) i += 1;
    if (start === i) fail("jeton inattendu");
    return text.slice(start, i);
  };

  const parseValue = () => {
    skip();
    const char = text[i];
    if (char === "{") return parseDict();
    if (char === "(") return parseArray();
    if (char === '"') {
      i += 1;
      let out = "";
      while (i < text.length && text[i] !== '"') {
        if (text[i] === "\\") i += 1;
        out += text[i];
        i += 1;
      }
      if (i >= text.length) fail("chaîne non fermée");
      i += 1;
      return out;
    }
    return parseBare();
  };

  const expect = (token) => {
    skip();
    if (text[i] !== token) fail(`« ${token} » attendu, trouvé « ${text[i] ?? "EOF"} »`);
    i += 1;
  };

  const parseDict = () => {
    expect("{");
    const out = {};
    for (;;) {
      skip();
      if (text[i] === "}") {
        i += 1;
        return out;
      }
      const key = parseValue();
      if (Object.hasOwn(out, key)) fail(`clé dupliquée : ${key}`);
      expect("=");
      out[key] = parseValue();
      expect(";");
    }
  };

  const parseArray = () => {
    expect("(");
    const out = [];
    for (;;) {
      skip();
      if (text[i] === ")") {
        i += 1;
        return out;
      }
      out.push(parseValue());
      skip();
      if (text[i] === ",") {
        i += 1;
        continue;
      }
      skip();
      if (text[i] === ")") {
        i += 1;
        return out;
      }
      fail("« , » ou « ) » attendu dans le tableau");
    }
  };

  const value = parseValue();
  skip();
  if (i < text.length) fail("données résiduelles après la racine");
  return value;
}

let plist = null;
try {
  plist = parseOpenStep(pbx);
  check(
    typeof plist.rootObject === "string",
    "pbxproj : rootObject absent ou invalide"
  );

  const objects = plist.objects ?? {};
  check(
    typeof objects === "object" && !Array.isArray(objects),
    "pbxproj : section objects illisible"
  );

  for (const [id, object] of Object.entries(objects)) {
    const isa = object?.isa;
    check(KNOWN_ISA.has(isa), `pbxproj : isa inconnu « ${isa} » (objet ${id})`);
  }

  // Chaque objet référencé (hors racine) doit exister dans `objects`.
  const collectIds = (value, found = new Set()) => {
    if (typeof value === "string") {
      if (/^[0-9A-F]{24}$/.test(value)) found.add(value);
    } else if (Array.isArray(value)) {
      value.forEach((item) => collectIds(item, found));
    } else if (value && typeof value === "object") {
      Object.values(value).forEach((item) => collectIds(item, found));
    }
    return found;
  };

  const missing = [...collectIds(objects)].filter((id) => !objects[id]);
  check(missing.length === 0, `pbxproj : objets référencés mais non définis -> ${missing.join(", ")}`);
} catch (error) {
  errors.push(`pbxproj illisible par Xcode : ${error.message}`);
}

// ---------------------------------------------------------------------------
// 2. .pbxproj <-> fichiers réels
// ---------------------------------------------------------------------------

// Seules les références en `sourceTree = "<group>"` pointent vers le disque :
// les produits (.app/.xctest) vivent dans BUILT_PRODUCTS_DIR (au build).
const fileRefPaths = new Set();
for (const match of pbx.matchAll(
  /isa = PBXFileReference;[^\n]*?path = "?([^";]+)"?;[^\n]*?sourceTree = "<group>";/g
)) {
  fileRefPaths.add(match[1]);
}

for (const path of fileRefPaths) {
  check(entryNames.has(path), `pbxproj référence un fichier absent du disque : ${path}`);
}

const swiftNames = new Set(swiftFiles.map((f) => f.split("/").pop()));
for (const path of fileRefPaths) {
  if (path.endsWith(".swift")) swiftNames.delete(path);
}
const orphanSwift = [...swiftNames].sort();
check(
  orphanSwift.length === 0,
  `Sources Swift absentes du .pbxproj (jamais compilées) -> ${orphanSwift.join(", ")}`
);

check(
  /Preview Assets\.xcassets in Resources/.test(pbx),
  "Preview Assets.xcassets n'est pas dans la phase Resources"
);
check(
  /Assets\.xcassets in Resources/.test(pbx),
  "Assets.xcassets n'est pas dans la phase Resources"
);

// ---------------------------------------------------------------------------
// 3. Paramètres de build attendus
// ---------------------------------------------------------------------------

const expectations = [
  ["PRODUCT_BUNDLE_IDENTIFIER = com.example.myapp;", "bundle identifier de l'app"],
  ["IPHONEOS_DEPLOYMENT_TARGET = 17.0;", "cible iOS 17.0"],
  ["GENERATE_INFOPLIST_FILE = YES;", "Info.plist généré"],
  ["SWIFT_VERSION = 5.0;", "version du langage Swift"],
  ["productType = \"com.apple.product-type.application\";", "cible application"],
  ["productType = \"com.apple.product-type.bundle.unit-test\";", "cible de tests unitaires"],
  ["productType = \"com.apple.product-type.bundle.ui-testing\";", "cible de tests UI"],
];
for (const [needle, label] of expectations) {
  check(pbx.includes(needle), `pbxproj : ${label} manquant (${needle})`);
}

// ---------------------------------------------------------------------------
// 4. Schéma partagé
// ---------------------------------------------------------------------------

const schemePath = join(
  root,
  "MyApp.xcodeproj",
  "xcshareddata",
  "xcschemes",
  "MyApp.xcscheme"
);
check(existsSync(schemePath), "Schéma partagé MyApp.xcscheme manquant (xcodebuild/test bloqués)");

if (existsSync(schemePath)) {
  const scheme = readFileSync(schemePath, "utf8");
  for (const match of scheme.matchAll(/BlueprintIdentifier = "([0-9A-F]{24})"/g)) {
    check(
      definedIds.has(match[1]),
      `Schéma : BlueprintIdentifier inconnu du pbxproj (${match[1]})`
    );
  }
  check(/<TestAction/.test(scheme), "Schéma : TestAction manquante");
}

// ---------------------------------------------------------------------------
// 5. Assets catalog : JSON valides
// ---------------------------------------------------------------------------

for (const file of allFiles.filter((f) => f.endsWith("Contents.json"))) {
  try {
    JSON.parse(readFileSync(file, "utf8"));
  } catch (error) {
    errors.push(`JSON invalide : ${relative(file)} (${error.message})`);
  }
}

const assetRoots = allDirs.filter((f) => f.endsWith(".xcassets"));
check(assetRoots.length >= 1, "Aucun asset catalog détecté");

// ---------------------------------------------------------------------------
// 6. Sanity checks Swift
// ---------------------------------------------------------------------------

const mainCount = swiftFiles.filter((f) =>
  /@main/.test(readFileSync(f, "utf8"))
).length;
check(mainCount === 1, `Déclaration @main attendue exactement une fois (trouvée : ${mainCount})`);

const appImport = swiftFiles.filter((f) =>
  /@testable import MyApp\b/.test(readFileSync(f, "utf8"))
);
check(appImport.length >= 1, "Aucun test ne fait @testable import MyApp");

// Équilibre grossier des accolades (les strings interpolées faussent rarement
// ce comptage sur des fichiers courts ; en cas de doute, l'éditeur le signale).
for (const file of swiftFiles) {
  const source = readFileSync(file, "utf8");
  let balance = 0;
  for (const char of source) {
    if (char === "{") balance += 1;
    else if (char === "}") balance -= 1;
  }
  if (balance !== 0) {
    warnings.push(`${relative(file)} : ${Math.abs(balance)} accolade(s) ${balance > 0 ? "non fermée(s)" : "en trop"}`);
  }
}

// ---------------------------------------------------------------------------
// Rapport
// ---------------------------------------------------------------------------

console.log(`\nValidation du projet iOS — ${relative(root) || "."}`);
console.log(
  `  ${swiftFiles.length} fichier(s) Swift, ${definedIds.size} objet(s) pbxproj, ` +
    `${fileRefPaths.size} référence(s) de fichiers.\n`
);

for (const message of warnings) console.log(`  ⚠  ${message}`);

if (errors.length === 0) {
  console.log(`  ✓ ${warnings.length} avertissement(s), 0 erreur — structure cohérente.\n`);
  console.log("  Prochaine étape (sur Mac) : open MyApp.xcodeproj\n");
  process.exit(0);
}

for (const message of errors) console.log(`  ✗  ${message}`);
console.log(`\n  ${errors.length} erreur(s), ${warnings.length} avertissement(s).\n`);
process.exit(1);
