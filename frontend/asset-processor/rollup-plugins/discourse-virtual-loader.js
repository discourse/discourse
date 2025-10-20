import rollupVirtualImports from "../rollup-virtual-imports";

export default function discourseVirtualLoader({ basePath, modules, opts }) {
  const availableVirtualImports = opts.isTheme
    ? rollupVirtualImports
    : {
        "virtual:main": rollupVirtualImports["virtual:main"],
      };

  return {
    name: "discourse-virtual-loader",
    resolveId(source) {
      if (availableVirtualImports[source]) {
        return `${basePath}${source}`;
      }
    },
    load(id) {
      if (!id.startsWith(basePath)) {
        return;
      }

      const fromBase = id.slice(basePath.length);

      if (availableVirtualImports[fromBase]) {
        return availableVirtualImports[fromBase](modules, opts, basePath, this);
      }
    },
  };
}
