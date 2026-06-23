import { dirname, relative } from "path";

export default function discourseExternalLoader({ basePath }) {
  return {
    name: "discourse-external-loader",
    async resolveId(source, context, options) {
      if (source.startsWith(basePath)) {
        return this.resolve(`./${relative(dirname(context), source)}`, context);
      }

      if (!source.startsWith(".")) {
        if (source.startsWith("discourse/plugins/")) {
          const mode = options.attributes.discoursePlugin;
          if (![undefined, "optional", "required"].includes(mode)) {
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
