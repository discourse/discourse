const DYNAMIC_CHUNK_NAME_COMMENT_REGEX =
  /import\(\s*\/\*\s*dynamicChunkName:\s*"([^"]+)"\s*\*\/\s*"([^"]+)"\s*\)/g;

function embroiderRouteName(facadeModuleId) {
  const match = facadeModuleId.match(
    /-embroider-route-entrypoint\.js:route=(.+)$/
  );
  if (match) {
    return `route-${match[1].replaceAll(/\W/g, "-")}`;
  }
}

function emberInspectorName(facadeModuleId) {
  if (facadeModuleId.includes("@embroider/legacy-inspector-support")) {
    return `ember-inspector-support`;
  }
}

export default function discourseChunkNamesPlugin() {
  const chunkNamesFromComments = new Map();

  return {
    name: "discourse-chunk-names",

    // Finds all dynamicChunkName comments in our source files, and adds them
    // to the list of chunkNamesFromComments for later use in the chunkFileNames hook.
    // Regex is not ideal... but this isn't worth the cost of a proper AST parse.
    // Does not actually transform any files.
    transform: {
      filter: {
        id: { exclude: /\/node_modules\// },
        code: DYNAMIC_CHUNK_NAME_COMMENT_REGEX,
      },

      async handler(code, id) {
        await Promise.all(
          [...code.matchAll(DYNAMIC_CHUNK_NAME_COMMENT_REGEX)].map(
            async ([, name, specifier]) => {
              const resolved = await this.resolve(specifier, id).catch(
                () => null
              );
              if (resolved?.id) {
                chunkNamesFromComments.set(resolved.id, name);
              }
            }
          )
        );

        return null;
      },
    },

    outputOptions(options) {
      const original = options.chunkFileNames;
      return {
        ...options,
        chunkFileNames: (chunk) => {
          if (!chunk.isDynamicEntry) {
            return original.replaceAll("[name]", "chunk");
          }

          if (!chunk.facadeModuleId) {
            return original;
          }

          const name =
            chunkNamesFromComments.get(chunk.facadeModuleId) ||
            embroiderRouteName(chunk.facadeModuleId) ||
            emberInspectorName(chunk.facadeModuleId);

          return name ? original.replaceAll("[name]", () => name) : original;
        },
      };
    },
  };
}
