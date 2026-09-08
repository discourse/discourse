import {
  cpSync,
  globSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { basename, dirname, normalize, relative, resolve } from "node:path";
import generateDtsBundle from "./dts-generator.js";
import processPackageJson from "./process-package-json.js";

const packageNames = [
  "@ember-compat/tracked-built-ins",
  "@ember/render-modifiers",
  "@ember/string",
  "@ember/test-helpers",
  "@floating-ui/dom",
  "@glimmer/component",
  "@glimmer/syntax",
  // "@glint/ember-tsc", is already a plugin/theme devDependency
  "@glint/template",
  "@types/jquery",
  "@types/qunit",
  "@types/rsvp",
  "@types/sinon",
  "discourse-i18n",
  "ember-modifier",
  "ember-qunit",
  "ember-source",
  "ember-truth-helpers",
  "pretender",
];

// A module whose default export is a namespace hides that namespace's types
// from consumers' declaration emit, which then expands them structurally
// without bound. Exporting the namespace by name gives the types a path.
function exportDefaultNamespaces(dts) {
  return dts.replace(/^(\t) namespace (\w+) \{$/gm, (line, indent, name) =>
    new RegExp(`^\\texport default ${name};$`, "m").test(dts)
      ? `${indent}export namespace ${name} {`
      : line
  );
}

(async function () {
  try {
    rmSync("./external-types", { recursive: true });
  } catch {}
  mkdirSync("./external-types");

  for (const entry of packageNames) {
    let packageName;
    let packagePath;
    if (typeof entry === "string") {
      packageName = entry;
      packagePath = `../discourse/node_modules/${packageName}`;
    } else {
      packageName = entry.packageName;
      packagePath = entry.packagePath;
    }

    // Read package.json
    let packageJson;
    try {
      packageJson = JSON.parse(
        readFileSync(`${packagePath}/package.json`, "utf-8")
      );
    } catch {
      throw new Error(`Package '${packageName}' not found`);
    }

    const targetPackagePath = `./external-types/${packageName.replace("@types/", "").replace("@", "").replace("/", "__")}`;

    mkdirSync(targetPackagePath, { recursive: true });

    // Get all the exported .d.ts paths
    const exportedDtsPaths = processPackageJson(packageJson, packagePath);

    // Copy the license and package.json
    const licenses = globSync(`${packagePath}/LICENSE*`);
    if (licenses.length > 0) {
      cpSync(licenses[0], `${targetPackagePath}/${basename(licenses[0])}`);
    }

    packageJson["__typesVersions"] = packageJson["typesVersions"];
    delete packageJson["typesVersions"];

    packageJson["__types"] = packageJson["types"];

    if (packageName === "ember-source") {
      packageJson["types"] = "types/stable/index.d.ts";
    } else {
      packageJson["types"] = "index.d.ts";
    }

    writeFileSync(
      `${targetPackagePath}/package.json`,
      JSON.stringify(packageJson, null, "  ")
    );

    // This one needs no changes thanks to `declare module` that's used extensively
    if (packageName === "ember-source") {
      // Copy **all** .d.ts files, and wrap those present in `exportedDtsPaths`
      // in a `declare module ...` block
      const dtsPaths = globSync(`${packagePath}/**/*.d.{ts,mts,cts}`);
      for (const path of dtsPaths) {
        const relativePath = relative(packagePath, path);
        mkdirSync(`${targetPackagePath}/${dirname(relativePath)}`, {
          recursive: true,
        });

        cpSync(path, `${targetPackagePath}/${relativePath}`);
      }

      writeFileSync(
        `${targetPackagePath}/types/index.d.ts`,
        'export * from "./stable/index";\n'
      );
    } else {
      function transformPath(relativePath) {
        // Declarations emitted by newer TypeScript keep explicit extensions on
        // their relative imports (e.g. `../utils/foo.ts`), while the keys in
        // `exportedDtsPaths` are extensionless. Strip any `.ts`/`.mts`/`.cts`
        // (or `.d.ts`) suffix so both forms line up for the lookup below.
        relativePath = relativePath.replace(/\.(d\.)?[cm]?ts$/, "");
        const modulePrefix = exportedDtsPaths.get(relativePath);
        if (modulePrefix) {
          let modulePath = relativePath;
          if (
            modulePrefix.remove &&
            modulePath.startsWith(modulePrefix.remove)
          ) {
            modulePath = modulePath.replace(modulePrefix.remove, "");
          }
          if (modulePrefix.add) {
            modulePath = [modulePrefix.add, modulePath]
              .filter(Boolean)
              .join("/");
          }
          modulePath = modulePath
            .replace(/^\//, "")
            .replace(/(index)?\.d\.[cm]?ts$/, "");
          modulePath = [packageName.replace(/@types\//, ""), modulePath]
            .filter(Boolean)
            .join("/");
          return modulePath.replace(/\/index$/, "");
        }
      }

      const out = `${targetPackagePath}/index.d.ts`;
      await generateDtsBundle({
        project: resolve(packagePath) + "/",
        out,
        resolveModuleId({ currentModuleId }) {
          return transformPath(currentModuleId);
        },
        resolveModuleImport({ importedModuleId, currentModuleId }) {
          if (importedModuleId.startsWith(".")) {
            return transformPath(
              normalize(`${dirname(currentModuleId)}/${importedModuleId}`)
            );
          } else {
            return importedModuleId;
          }
        },
      });
      writeFileSync(out, exportDefaultNamespaces(readFileSync(out, "utf-8")));
    }
  }
})().then(() => {
  // eslint-disable-next-line no-console
  console.log("Done");
});
