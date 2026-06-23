import { dirname, relative } from "path";

export default function discourseExternalLoader({ basePath }) {
  return {
    name: "discourse-external-loader",
    async resolveId(source, context, options) {
      if (source.startsWith(basePath)) {
        return this.resolve(`./${relative(dirname(context), source)}`, context);
      }

      if (!source.startsWith(".")) {
        // Cross-plugin imports are optional by default, resolving to a null stub
        // when the target plugin isn't installed; `with { discoursePlugin:
        // "required" }` opts into a hard dependency instead. Optional imports
        // get an `?optional` marker baked into their external id, so the
        // optionality travels through rollup's module graph (and therefore
        // `chunk.imports`) without a side channel; BabelResolvePluginImports
        // reads the marker back off the import source.
        if (source.startsWith("discourse/plugins/")) {
          const mode = options.attributes.discoursePlugin;
          if (
            mode !== undefined &&
            mode !== "optional" &&
            mode !== "required"
          ) {
            throw new Error(
              `Invalid \`discoursePlugin\` import attribute "${mode}" on "${source}". Allowed values are "optional" and "required".`
            );
          }

          if (mode !== "required") {
            return { id: `${source}?optional`, external: true };
          }
        }

        return { id: source, external: true };
      }
    },
  };
}
