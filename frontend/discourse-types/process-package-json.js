import { compareVersions } from "compare-versions";
import { existsSync, globSync } from "node:fs";

export default function processPackageJson(packageJson, packagePath) {
  const paths = new Set();

  if (packageJson["exports"]) {
    for (const [key, value] of Object.entries(packageJson["exports"])) {
      const types =
        value.types ||
        value.import?.types ||
        value.default?.development?.types ||
        value.default?.default?.types ||
        value.require?.types;
      if (types) {
        paths.add({ path: types, importPathPrefix: key });
      }
    }
  }

  if (paths.size === 0 && packageJson["types"]) {
    paths.add({ path: packageJson["types"] });
  }

  if (paths.size === 0 && packageJson["typings"]) {
    paths.add({ path: packageJson["typings"] });
  }

  if (paths.size === 0 && packageJson["typesVersions"]) {
    let config = packageJson["typesVersions"]["*"];

    if (!config) {
      const highestVersion = Object.keys(packageJson["typesVersions"])
        .sort(compareVersions)
        .at(-1);
      config = packageJson["typesVersions"][highestVersion];
    }

    for (const entry of Object.values(config)) {
      let path = entry[0];
      if (!path.endsWith("/*") && !/\.d\.[cm]?ts$/.test(path)) {
        path = `${path}/*`;
      }

      // TODO: add importPathPrefix here too?
      paths.add({ path });
    }
  }

  if (paths.size === 0) {
    // sometimes there is a index.d.ts and no package.json entries...
    paths.add({ types: "index.d.ts" });
    paths.add({ types: "index.d.cts" });
    paths.add({ types: "index.d.mts" });
  }

  const expandedPaths = new Map();

  for (let { path, importPathPrefix } of paths) {
    if (importPathPrefix) {
      importPathPrefix = importPathPrefix
        .replace(/^\.\/?/, "")
        .replace(/\/?\*$/, "");
    }

    path = path.replace(/^\.\/?/, "");
    const modulePrefix = path.replace(/\/?\*$/, "").replace(/\*.*$/, "");

    if (path.includes("*")) {
      const entries = globSync(
        path.replace("*", "**/*").replace(/\*$/, "*.d.{ts,mts,cts}"),
        {
          cwd: packagePath,
        }
      );

      for (const entry of entries) {
        expandedPaths.set(entry, { from: modulePrefix, to: importPathPrefix });
      }
    } else if (existsSync(`${packagePath}/${path}`)) {
      expandedPaths.set(path.replace(/^\.\//, ""), {
        from: modulePrefix,
        to: importPathPrefix,
      });
    }
  }

  return expandedPaths;
}
