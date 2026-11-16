import { readFileSync } from "fs";
import { isAbsolute, join, relative } from "path";

const NODE_MODULES = "/node_modules/";

/**
 * A memoized `normalizeModuleId`, whose ids are the same on every machine.
 * Watch rebuilds reuse it, so package versions refresh on restart.
 *
 * @param {string} root
 * @returns {(id: string) => string}
 */
export function moduleIdNormalizer(root) {
  const versionOf = memoize(readPackageVersion);
  return memoize((id) => normalizeModuleId(id, root, versionOf));
}

function memoize(fn) {
  const cache = new Map();
  return (key) => {
    if (!cache.has(key)) {
      cache.set(key, fn(key));
    }
    return cache.get(key);
  };
}

/**
 * Makes a module id stable across machines: relative to `root`, and
 * `<package>@<version>/<path>` for node_modules, whatever the package
 * manager's directory layout.
 */
export function normalizeModuleId(id, root, versionOf = () => undefined) {
  let prefix = "";
  let path = id;
  if (path.startsWith("\0")) {
    path = path.slice(1);
    prefix = path.startsWith("virtual:") ? "" : "virtual:";
  }

  // Virtual ids like `virtual:some-plugin:/abs/path.js` embed a path.
  const scheme = path.match(/^((?:[\w-]+:)+)(\/.*)$/);
  if (scheme) {
    return `${prefix}${scheme[1]}${normalizeModuleId(scheme[2], root, versionOf)}`;
  }

  const [file, query] = splitQuery(path);
  const posixFile = file.replaceAll("\\", "/");
  const packageStart = posixFile.lastIndexOf(NODE_MODULES);

  if (packageStart !== -1) {
    const inPackages = posixFile.slice(packageStart + NODE_MODULES.length);
    const nameParts = inPackages.startsWith("@") ? 2 : 1;
    const segments = inPackages.split("/");
    const packageName = segments.slice(0, nameParts).join("/");
    const rest = segments.slice(nameParts).join("/");
    const version = versionOf(
      posixFile.slice(0, packageStart + NODE_MODULES.length) + packageName
    );
    return `${prefix}${packageName}${version ? `@${version}` : ""}/${rest}${query}`;
  }

  if (isAbsolute(file)) {
    return `${prefix}${relative(root, file).replaceAll("\\", "/")}${query}`;
  }
  return `${prefix}${posixFile}${query}`;
}

function splitQuery(path) {
  const index = path.indexOf("?");
  return index === -1 ? [path, ""] : [path.slice(0, index), path.slice(index)];
}

function readPackageVersion(packageDir) {
  try {
    return JSON.parse(readFileSync(join(packageDir, "package.json"), "utf8"))
      .version;
  } catch {
    return undefined;
  }
}
