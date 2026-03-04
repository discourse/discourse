import rollupVirtualImports from "../rollup-virtual-imports";

export default function discourseVirtualLoader({
  basePath,
  entrypoints,
  opts,
  isTheme,
}) {
  const availableVirtualImports = isTheme
    ? rollupVirtualImports
    : {
        "virtual:entrypoint": rollupVirtualImports["virtual:entrypoint"],
      };

  return {
    name: "discourse-virtual-loader",
    resolveId(source) {
      if (
        availableVirtualImports[source] ||
        source.startsWith("virtual:entrypoint:")
      ) {
        return `${basePath}${source}`;
      }
    },
    load(id) {
      if (!id.startsWith(basePath)) {
        return;
      }

      const fromBase = id.slice(basePath.length);

      if (fromBase.startsWith("virtual:entrypoint:")) {
        const entrypointName = fromBase.replace("virtual:entrypoint:", "");
        const entrypointConfig = entrypoints[entrypointName];

        return availableVirtualImports["virtual:entrypoint"](
          entrypointConfig.modules,
          opts,
          {
            basePath,
            context: this,
          }
        );
      } else if (availableVirtualImports[fromBase]) {
        return availableVirtualImports[fromBase](opts);
      }
    },
  };
}
