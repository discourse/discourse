import { compareVersions } from "compare-versions";
import { existsSync, globSync } from "node:fs";

function selectTypesVersions(packageJson) {
  const typesVersions = packageJson["typesVersions"];
  if (!typesVersions) {
    return;
  }

  if (typesVersions["*"]) {
    return typesVersions["*"];
  }

  const highestVersion = Object.keys(typesVersions)
    .sort(compareVersions)
    .at(-1);
  return typesVersions[highestVersion];
}

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

  const typesVersionsConfig = selectTypesVersions(packageJson);
  const typesEntry = packageJson["types"] || packageJson["typings"];

  if (paths.size === 0 && typesEntry) {
    // TypeScript redirects the `types` entry through `typesVersions`, so the
    // declarations come from the file it would pick.
    const redirect = typesVersionsConfig?.["*"]?.[0];
    paths.add(
      redirect
        ? redirect.replace("*", typesEntry.replace(/^\.\//, ""))
        : typesEntry
    );
  }

  if (paths.size === 0 && typesVersionsConfig) {
    for (const entry of Object.values(typesVersionsConfig)) {
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
    const modulePrefix = path
      .replace(/\/?\*$/, "")
      .replace(/\*.*$/, "")
      .replace(/\.d\.ts$/, "");

    if (path.includes("*")) {
      const entries = globSync(
        path.replace("*", "**/*").replace(/\*$/, "*.d.{ts,mts,cts}"),
        {
          cwd: packagePath,
        }
      );

      for (let entry of entries) {
        entry = entry.replace(/\.d\.ts$/, "");
        if (!expandedPaths.has(entry)) {
          expandedPaths.set(entry, {
            remove: modulePrefix,
            add: importPathPrefixes.get(entry),
          });
        }
      }
    } else if (existsSync(`${packagePath}/${path}`)) {
      const entry = path.replace(/^\.\//, "").replace(/\.d\.ts$/, "");

      if (!expandedPaths.has(entry)) {
        expandedPaths.set(entry, {
          remove: modulePrefix,
          add: prefix,
        });
      }
    }
  }

  return expandedPaths;
}
