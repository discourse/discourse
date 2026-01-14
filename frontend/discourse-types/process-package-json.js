import { compareVersions } from "compare-versions";
import { existsSync, globSync } from "node:fs";

export default function processPackageJson(packageJson, packagePath) {
  const paths = new Set();
  const importPathPrefixes = new Map();

  if (packageJson["exports"]) {
    for (const [key, value] of Object.entries(packageJson["exports"])) {
      const types =
        value.types ||
        value.import?.types ||
        value.default?.development?.types ||
        value.default?.default?.types ||
        value.require?.types ||
        (typeof value === "string" && /\.d\.[cm]?ts$/.test(value) && value);
      if (types) {
        paths.add(types);

        if (!importPathPrefixes.has(types)) {
          importPathPrefixes.set(
            types,
            key.replace(/^\.\/?/, "").replace(/\/?\*$/, "")
          );
        }
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
      if (!path.endsWith("/*") && !/\.d\.[cm]?ts$/.test(path)) {
        path = `${path}/*`;
      }

      // TODO: add importPathPrefix here too?
      paths.add(path);
    }
  }

  if (paths.size === 0) {
    // sometimes there is a index.d.ts and no package.json entries...
    paths.add("index.d.ts");
    paths.add("index.d.cts");
    paths.add("index.d.mts");
  }

  const expandedPaths = new Map();

  for (let path of paths) {
    let prefix = importPathPrefixes.get(path);

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
        if (!expandedPaths.has(entry)) {
          expandedPaths.set(entry, {
            from: modulePrefix,
            to: importPathPrefixes.get(entry),
          });
        }
      }
    } else if (existsSync(`${packagePath}/${path}`)) {
      const entry = path.replace(/^\.\//, "");

      if (!expandedPaths.has(entry)) {
        expandedPaths.set(entry, {
          from: modulePrefix,
          to: prefix,
        });
      }
    }
  }

  return expandedPaths;
}
