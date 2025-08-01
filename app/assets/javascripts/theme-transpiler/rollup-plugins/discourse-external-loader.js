export default function discourseExternalLoader({ basePath }) {
  return {
    name: "discourse-external-loader",
    async resolveId(source) {
      if (source.startsWith(basePath)) {
        return `/${source}`;
      }

      if (!source.startsWith(".")) {
        return { id: source, external: true };
      }
    },
  };
}
