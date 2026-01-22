// TODO: rename to generate-external-types or similar
// import findModuleInsertionPoint from "./find-module-insertion-point.js";
import generateDtsBundle from "dts-generator";
import {
  cpSync,
  globSync,
  mkdirSync,
  readFileSync,
  renameSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { basename, dirname, normalize, relative, resolve } from "node:path";
import processPackageJson from "./process-package-json.js";

// const fileName = "external-types.d.ts";
const packageNames = [
  "@ember-compat/tracked-built-ins",
  "@ember/render-modifiers",
  "@ember/string",
  "@ember/test-helpers",
  "@floating-ui/dom",
  "@glimmer/component",
  "@glimmer/syntax",
  // "@glint/ember-tsc", in plugin/theme devDeps
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
  // "make-plural",
  // {
  //   packageName: "@messageformat/runtime",
  //   packagePath: "../discourse-i18n/node_modules/@messageformat/runtime",
  // },
  // {
  //   packageName: "@glimmer/validator",
  //   packagePath: "./node_modules/@glimmer/validator",
  // },
];

(async function () {
  try {
    rmSync("./external-types", { recursive: true });
  } catch {}
  mkdirSync("./external-types");

  // let output = "";

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

    console.log(targetPackagePath);
    console.log(exportedDtsPaths);

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

    // cpSync(`${packagePath}/package.json`, `${targetPackagePath}/package.json`);
    writeFileSync(
      `${targetPackagePath}/package.json`,
      JSON.stringify(packageJson, null, "  ")
    );

    // this one is ready to go, thanks to `declare module` used everywhere
    if (packageName === "ember-source") {
      // Copy **all** .d.ts files, and wrap those present in `exportedDtsPaths`
      // in a `declare module ...` block
      const dtsPaths = globSync(`${packagePath}/**/*.d.{ts,mts,cts}`);
      for (const path of dtsPaths) {
        // let dts = readFileSync(path, "utf-8");

        const relativePath = relative(packagePath, path);
        mkdirSync(`${targetPackagePath}/${dirname(relativePath)}`, {
          recursive: true,
        });

        cpSync(path, `${targetPackagePath}/${relativePath}`);
      }
    } else {
      function transformPath(relativePath) {
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
          // if (
          //   !/^declare module ['"].+['"] {/.test(dts) &&
          //   !dts.includes("/// <reference")
          // ) {
          //   const position = findModuleInsertionPoint(dts);
          //   dts =
          //     dts.slice(0, position) +
          //     `\ndeclare module '${modulePath}' {\n` +
          //     dts.slice(position) +
          //     "\n}";
          //   // dts = `declare module '${modulePath}' {\n${dts}\n}`;
          // }
          return modulePath.replace(/\/index$/, "");
        }
        // writeFileSync(`${targetPackagePath}/${relativePath}`, dts);
      }

      const hasTsconfig = globSync(`${packagePath}/tsconfig.json`).length > 0;

      // dts-generator needs a tsconfig
      if (hasTsconfig) {
        renameSync(
          `${packagePath}/tsconfig.json`,
          `${packagePath}/__tsconfig.json`
        );
      }
      writeFileSync(`${packagePath}/tsconfig.json`, "");

      try {
        await generateDtsBundle.default({
          // name: "package-name",
          project: resolve(packagePath) + "/",
          out: `${targetPackagePath}/index.d.ts`,
          resolveModuleId({ currentModuleId }) {
            // console.log(`resolveModuleId: ${currentModuleId}`);
            const path = transformPath(currentModuleId);

            if (path) {
              return path;
            } else {
              // TODO: somehow remove the whole module declaration
            }
          },
          resolveModuleImport({ importedModuleId, currentModuleId }) {
            // console.log(
            //   `resolveModuleImport: ${importedModuleId} (in ${currentModuleId})`
            // );
            if (importedModuleId.startsWith(".")) {
              return transformPath(
                normalize(`${dirname(currentModuleId)}/${importedModuleId}`)
              );
            } else {
              return importedModuleId;
            }
          },
        });
      } finally {
        rmSync(`${packagePath}/tsconfig.json`);

        if (hasTsconfig) {
          renameSync(
            `${packagePath}/__tsconfig.json`,
            `${packagePath}/tsconfig.json`
          );
        }
      }

      // Add <reference /> entries to external-types.d.ts
      // for (const path of exportedDtsPaths.keys()) {
      //   if (
      //     // Don't reference private types...
      //     !/(^|\/)-private/.test(path) ||
      //     // ...except those:
      //     (packageName === "@glint/template" &&
      //       path === "-private/integration.d.ts") ||
      //     (packageName === "@glint/ember-tsc" &&
      //       path === "types/-private/dsl/index.d.ts")
      //   ) {
      //     output += `/// <reference path="${targetPackagePath}/${path}" />\n`;
      //   }
      // }
    }

    // // Special handling for @glimmer/validator
    // const packagePath = "../discourse/node_modules/ember-source";
    // const packageName = "@glimmer/validator";
    // let packageJson;
    // try {
    //   packageJson = JSON.parse(
    //     readFileSync(`${packagePath}/package.json`, "utf-8")
    //   );
    // } catch {
    //   throw new Error(`Package '${packageName}' not found`);
    // }

    // const targetPackagePath = `./external-types/${packageName.replace("/", "__")}`;
    // mkdirSync(targetPackagePath);
    // cpSync(`${packagePath}/package.json`, `${targetPackagePath}/package.json`);

    // writeFileSync(`./${fileName}`, output);

    // console.log(`Done, written to: ${fileName}`);
  }
})().then(() => {
  console.log("Done");
});
