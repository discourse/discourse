import { compareVersions } from "compare-versions";
import { existsSync, globSync } from "node:fs";

export default function processPackageJson(packageJson, packagePath) {
  const paths = new Set();

  if (packageJson["exports"]) {
    for (const entry of Object.values(packageJson["exports"])) {
      const types =
        entry.types ||
        entry.import?.types ||
        entry.default?.development?.types ||
        entry.default?.default?.types ||
        entry.require?.types;
      if (types) {
        paths.add(types);
      }
    }
  }

  if (paths.size === 0 && packageJson["types"]) {
    paths.add(packageJson["types"]);
  }

  if (paths.size === 0 && packageJson["typings"]) {
    paths.add(packageJson["typings"]);
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
      if (!path.endsWith("/*") && !path.endsWith(".d.ts")) {
        path = `${path}/*`;
      }

      paths.add(path);
    }
  }

  if (paths.size === 0) {
    // sometimes there is a index.d.ts and no package.json entries...
    paths.add("index.d.ts");
  }

  const expandedPaths = new Map();

  for (let path of paths) {
    path = path.replace(/^\.\/?/, "");
    const modulePrefix = path.replace(/\/?\*$/, "").replace(/\*.*$/, "");

    if (path.includes("*")) {
      const entries = globSync(
        path.replace("*", "**/*").replace(/\*$/, "*.d.ts"),
        {
          cwd: packagePath,
        }
      );

      for (const entry of entries) {
        expandedPaths.set(entry, { from: modulePrefix });
      }
    } else if (existsSync(`${packagePath}/${path}`)) {
      expandedPaths.set(path.replace(/^\.\//, ""), { from: modulePrefix });
    }
  }

  return expandedPaths;
}
