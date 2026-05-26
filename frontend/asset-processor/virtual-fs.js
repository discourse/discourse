// Minimal in-memory fs for `@rollup/browser`. Only implements what
// it actually needs for bundling.

const FILE_STATS = {
  isFile: () => true,
  isSymbolicLink: () => false,
};

export default function createVirtualFs(modules, basePath) {
  const files = new Map();
  const dirs = new Map();

  for (const [key, content] of Object.entries(modules)) {
    const path = basePath + key;
    files.set(path, content);

    const slash = path.lastIndexOf("/");
    const parent = path.slice(0, slash);
    let children = dirs.get(parent);
    if (!children) {
      children = [];
      dirs.set(parent, children);
    }
    children.push(path.slice(slash + 1));
  }

  return {
    async readFile(path) {
      const content = files.get(path);
      if (content === undefined) {
        throw new Error(`ENOENT: ${path}`);
      }
      return content;
    },

    async readdir(path) {
      const children = dirs.get(path);
      if (!children) {
        throw new Error(`ENOENT: ${path}`);
      }
      return children;
    },

    async lstat(path) {
      if (files.has(path)) {
        return FILE_STATS;
      }
      throw new Error(`ENOENT: ${path}`);
    },
  };
}
