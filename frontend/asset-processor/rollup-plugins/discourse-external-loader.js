import { dirname, relative } from "path";

export default function discourseExternalLoader({ basePath }) {
  return {
    name: "discourse-external-loader",
    async resolveId(source, context) {
      if (source.startsWith(basePath)) {
        return (
          (await this.resolve(
            `./${relative(dirname(context), source)}`,
            context
          )) || { id: source, external: true } // Might be in a different bundle for the same plugin
        );
      }

      if (!source.startsWith(".")) {
        return { id: source, external: true };
      }
    },
  };
}
