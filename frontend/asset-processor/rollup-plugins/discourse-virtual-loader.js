import rollupVirtualImports, {
  privateVirtualImports,
} from "../rollup-virtual-imports";

// Core modules that plugin and theme code reaches through a generated wrapper,
// so registrations carry the plugin or theme they came from.
const ATTRIBUTED_MODULES = {
  "discourse/lib/plugin-api": "virtual:attributed-plugin-api",
  "discourse/lib/api": "virtual:attributed-api-initializer",
};

// The leading null byte marks a synthetic module, and keeps the id out of reach
// of anything a plugin or theme could write in an import.
function privateId(basePath, name) {
  return `\0${basePath}${name}`;
}

function isPrivateId(id, basePath) {
  return Object.keys(privateVirtualImports).some(
    (name) => id === privateId(basePath, name)
  );
}

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
    resolveId(source, importer) {
      const attributed = ATTRIBUTED_MODULES[source];
      if (attributed) {
        // A wrapper's own import must reach the real module.
        if (!isPrivateId(importer, basePath)) {
          return privateId(basePath, attributed);
        }
        return;
      }

      if (
        availableVirtualImports[source] ||
        source.startsWith("virtual:entrypoint:") ||
        source.startsWith("virtual:route:")
      ) {
        return `${basePath}${source}`;
      }
    },
    load(id) {
      if (isPrivateId(id, basePath)) {
        return privateVirtualImports[id.slice(1 + basePath.length)](opts);
      }

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
            entrypointName,
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
