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
          entrypointName
        );
      } else if (fromBase.startsWith("virtual:route:")) {
        // Entrypoints are built from separate module lists but share one bundle-name
        // namespace, so the entrypoint is part of the id.
        const qualified = fromBase.replace("virtual:route:", "");
        const separator = qualified.indexOf(":");
        const entrypointName = qualified.slice(0, separator);
        const bundleName = qualified.slice(separator + 1);
        const entrypointConfig = entrypoints[entrypointName];

        const source =
          entrypointConfig &&
          availableVirtualImports["virtual:route"](
            entrypointConfig.modules,
            opts,
            bundleName
          );

        if (!source) {
          throw new Error(
            `No route bundle for "${bundleName}" in the ${entrypointName} entrypoint — no route files matched it.`
          );
        }

        return source;
      } else if (availableVirtualImports[fromBase]) {
        return availableVirtualImports[fromBase](opts);
      }
    },
  };
}
