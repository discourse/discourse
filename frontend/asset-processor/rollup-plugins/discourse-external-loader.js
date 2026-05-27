import { dirname, relative } from "path";

export default function discourseExternalLoader({ basePath }) {
  return {
    name: "discourse-external-loader",
    async resolveId(source, context) {
      if (source.startsWith(basePath)) {
        return this.resolve(`./${relative(dirname(context), source)}`, context);
      }

      if (!source.startsWith(".")) {
        return { id: source, external: true };
      }
    },
  };
}
