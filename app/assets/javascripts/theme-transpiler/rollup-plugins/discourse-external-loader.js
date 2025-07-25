export default function discourseExternalLoader() {
  return {
    name: "discourse-external-loader",
    async resolveId(source) {
      if (!source.startsWith(".")) {
        return { id: source, external: true };
      }
    },
  };
}
