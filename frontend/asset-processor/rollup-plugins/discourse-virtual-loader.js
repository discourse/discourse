import rollupVirtualImports from "../rollup-virtual-imports";

export default function discourseVirtualLoader({ themeBase, modules, opts }) {
  return {
    name: "discourse-virtual-loader",
    resolveId(source) {
      if (rollupVirtualImports[source]) {
        return `${themeBase}${source}`;
      }
    },
    load(id) {
      if (!id.startsWith(themeBase)) {
        return;
      }

      const fromBase = id.slice(themeBase.length);

      if (rollupVirtualImports[fromBase]) {
        return rollupVirtualImports[fromBase](modules, opts);
      }
    },
  };
}
