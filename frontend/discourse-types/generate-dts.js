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
  // "@glimmer/tracking", ?
  "@glint/template",
  "@types/qunit",
  "@types/rsvp",
  "ember-modifier",
  "ember-qunit",
  "ember-source",
];

try {
  rmSync("./external-types", { recursive: true });
} catch {}
mkdirSync("./external-types");

let output = "";

for (const packageName of packageNames) {
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

  const licenses = globSync(`${packagePath}/LICENSE*`);
  if (licenses.length > 0) {
    cpSync(licenses[0], `${targetPackagePath}/${basename(licenses[0])}`);
  }

  cpSync(`${packagePath}/package.json`, `${targetPackagePath}/package.json`);

  const exportedDtsPaths = processPackageJson(packageJson, packagePath);
  // console.log(exportedDtsPaths);

  const dtsPaths = globSync(`${packagePath}/**/*.d.{ts,mts,cts}`);
  for (const path of dtsPaths) {
    let dts = readFileSync(path, "utf-8");

    const relativePath = relative(packagePath, path);
    mkdirSync(`${targetPackagePath}/${dirname(relativePath)}`, {
      recursive: true,
    });

    // console.log(relativePath);

    const modulePath = [
      packageName,
      relativePath
        .replace(exportedDtsPaths.get(relativePath), "")
        .replace(/^\//, "")
        .replace(/(index)?\.d\.ts$/, ""),
    ]
      .filter(Boolean)
      .join("/");
    const moduleDefinition = `declare module "${modulePath}" {`;

    // console.log(
    //   `path: ${path}\nmap: ${exportedDtsPaths.get(relativePath)}\nmodulePath: ${modulePath}`
    // );

    if (!dts.includes(moduleDefinition)) {
      dts = `${moduleDefinition}\n${dts}\n}`;
    }

    writeFileSync(`${targetPackagePath}/${relativePath}`, dts);
  }

  for (const path of exportedDtsPaths.keys()) {
    output += `/// <reference path="${targetPackagePath}/${path}" />\n`;
  }
}

// TODO: is this handled?

// output += `
// declare module "@glint/ember-tsc/-private/dsl" {
//   export {
//     resolve,
//     resolveOrReturn,
//     templateExpression,
//     Globals,
//     AnyFunction,
//     AnyContext,
//     AnyBlocks,
//     InvokeDirect,
//     DirectInvokable,
//     Invoke,
//     InvokableInstance,
//     Invokable,
//     Context,
//     HasContext,
//     ModifierReturn,
//     ComponentReturn,
//     TemplateContext,
//     FlattenBlockParams,
//     NamedArgs,
//     NamedArgsMarker,
//     NamedArgNames,
//     UnwrapNamedArgs,
//   } from "./external-types/glint__ember-tsc/types/-private/dsl";
// }
// `;
// cpSync(
//   "./node_modules/@types/glint__ember-tsc/types/-private/dsl",
//   "./external-types/glint__ember-tsc/-private/dsl",
//   {
//     recursive: true,
//   }
// );

writeFileSync(`./${fileName}`, output);

// console.log(`Done, written to: ${fileName}`);
