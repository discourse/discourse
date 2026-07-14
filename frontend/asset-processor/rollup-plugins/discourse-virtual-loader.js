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
        "virtual:route": rollupVirtualImports["virtual:route"],
      };

  return {
    name: "discourse-virtual-loader",
    resolveId(source) {
      if (
        availableVirtualImports[source] ||
        source.startsWith("virtual:entrypoint:") ||
        source.startsWith("virtual:route:")
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
      } else if (fromBase.startsWith("virtual:route:")) {
        const routeName = fromBase.replace("virtual:route:", "");

        // Entrypoints share a compat-module namespace, so a route name belongs to exactly one
        // of them. Whichever entrypoint produced this bundle can render it.
        for (const { modules } of Object.values(entrypoints)) {
          try {
            return availableVirtualImports["virtual:route"](
              modules,
              opts,
              routeName
            );
          } catch {
            continue;
          }
        }

        throw new Error(`No route bundle for "${routeName}"`);
      } else if (availableVirtualImports[fromBase]) {
        return availableVirtualImports[fromBase](opts);
      }
    },
  };
}
