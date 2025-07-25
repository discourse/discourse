export default function discourseExtensionSearch() {
  return {
    name: "discourse-extension-search",
    async resolveId(source, context) {
      if (source.match(/\.\w+$/)) {
        // Already has an extension
        return null;
      }

      for (const ext of ["", ".js", ".gjs", ".hbs"]) {
        const resolved = await this.resolve(`${source}${ext}`, context);

        if (resolved) {
          return resolved;
        }
      }

      return null;
    },
  };
}
