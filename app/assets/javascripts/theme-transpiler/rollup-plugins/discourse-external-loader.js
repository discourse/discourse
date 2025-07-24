export default function discourseExternalLoader() {
  return {
    name: "discourse-external-loader",
    async resolveId(source, context) {
      if (source.startsWith("discourse/plugins/chat/")) {
        console.warn(
          "importing from chat plugin",
          source,
          context,
          await this.resolve(
            source.replace("discourse/plugins/chat/", "./"),
            ""
          )
        );
        return this.resolve(
          source.replace("discourse/plugins/chat/", "./"),
          "theme-0/index.js"
        );
      }
      if (!source.startsWith(".")) {
        return { id: source, external: true };
      }
    },
  };
}
