import {
  cpSync,
  globSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { basename, dirname, relative } from "node:path";
import processPackageJson from "./process-package-json.js";

const fileName = "external-types.d.ts";
const packageNames = [
  "@ember-compat/tracked-built-ins",
  "@ember/render-modifiers",
  "@ember/string",
  "@ember/test-helpers",
  "@floating-ui/dom",
  "@glimmer/component",
  "@glimmer/syntax",
  "@glint/ember-tsc",
  "@glint/template",
  "@types/jquery",
  "@types/qunit",
  "@types/rsvp",
  "@types/sinon",
  "discourse-i18n",
  "ember-modifier",
  "ember-qunit",
  "ember-source",
  "pretender",
];

try {
  rmSync("./external-types", { recursive: true });
} catch {}
mkdirSync("./external-types");

let output = "";

for (const packageName of packageNames) {
  // Read package.json
  const packagePath = `../discourse/node_modules/${packageName}`;
  let packageJson;
  try {
    packageJson = JSON.parse(
      readFileSync(`${packagePath}/package.json`, "utf-8")
    );
  } catch {
    throw new Error(`Package '${packageName}' not found`);
  }

  const targetPackagePath = `./external-types/${packageName.replace("/", "__")}`;

  mkdirSync(targetPackagePath);

  // Copy the license and package.json
  const licenses = globSync(`${packagePath}/LICENSE*`);
  if (licenses.length > 0) {
    cpSync(licenses[0], `${targetPackagePath}/${basename(licenses[0])}`);
  }

  cpSync(`${packagePath}/package.json`, `${targetPackagePath}/package.json`);

  // Get all the exported .d.ts paths
  const exportedDtsPaths = processPackageJson(packageJson, packagePath);

  // Copy **all** .d.ts files, and wrap those present in `exportedDtsPaths`
  // in a `declare module ...` block
  const dtsPaths = globSync(`${packagePath}/**/*.d.{ts,mts,cts}`);
  for (const path of dtsPaths) {
    let dts = readFileSync(path, "utf-8");

    const relativePath = relative(packagePath, path);
    mkdirSync(`${targetPackagePath}/${dirname(relativePath)}`, {
      recursive: true,
    });

    const modulePrefix = exportedDtsPaths.get(relativePath);

    if (modulePrefix) {
      let modulePath = relativePath;

      if (modulePrefix.remove && modulePath.startsWith(modulePrefix.remove)) {
        modulePath = modulePath.replace(modulePrefix.remove, "");
      }

      if (modulePrefix.add) {
        modulePath = [modulePrefix.add, modulePath].filter(Boolean).join("/");
      }

      modulePath = modulePath
        .replace(/^\//, "")
        .replace(/(index)?\.d\.[cm]?ts$/, "");

      modulePath = [packageName.replace(/@types\//, ""), modulePath]
        .filter(Boolean)
        .join("/");

      if (
        !/^declare module ['"].+['"] {/.test(dts) &&
        !dts.includes("/// <reference")
      ) {
        dts = `declare module '${modulePath}' {\n${dts}\n}`;
      }
    }

    writeFileSync(`${targetPackagePath}/${relativePath}`, dts);
  }

  // Add <reference /> entries to external-types.d.ts
  for (const path of exportedDtsPaths.keys()) {
    if (
      // Don't reference private types...
      !/(^|\/)-private/.test(path) ||
      // ...except those:
      (packageName === "@glint/template" &&
        path === "-private/integration.d.ts") ||
      (packageName === "@glint/ember-tsc" &&
        path === "types/-private/dsl/index.d.ts")
    ) {
      output += `/// <reference path="${targetPackagePath}/${path}" />\n`;
    }
  }
}

writeFileSync(`./${fileName}`, output);
// eslint-disable-next-line no-console
console.log(`Done, written to: ${fileName}`);
