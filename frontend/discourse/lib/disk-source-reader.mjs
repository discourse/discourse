import { readFileSync, realpathSync } from "fs";
import { isAbsolute, relative, sep } from "path";

/*
 * Builds the `readSource` callback that `discourse-source-imports` needs when
 * resolving against a real filesystem, as opposed to an in-memory module map.
 *
 * A source import inlines raw file text into the bundle, so this is the boundary
 * deciding what may be inlined. Paths are resolved to their real location first,
 * so a symlink cannot be used to reach outside the root.
 *
 * Lives apart from the plugin so that nothing importing the plugin pulls `fs` in;
 * the asset processor bundles the plugin for an environment without it.
 */
export default function createDiskSourceReader(rootPath) {
  const root = realpathSync(rootPath);

  return function readSource(id) {
    let realPath;

    try {
      realPath = realpathSync(id);
    } catch {
      return undefined;
    }

    const relativePath = relative(root, realPath);

    if (
      !relativePath ||
      relativePath.startsWith("..") ||
      isAbsolute(relativePath) ||
      relativePath.split(sep).includes("node_modules")
    ) {
      return undefined;
    }

    try {
      return readFileSync(realPath, "utf8");
    } catch {
      return undefined;
    }
  };
}
