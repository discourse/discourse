export default function discourseFileSearch() {
  return {
    name: "discourse-file-search",
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

      // If lookup has no extension, and is not /index already, check for an /index file
      if (!source.match(/\.\w+$/) && !source.endsWith("/index")) {
        const resolved = await this.resolve(`${source}/index`, context, {
          skipSelf: false, // We want extensionsearch on the `/index` lookup as well
        });
        if (resolved) {
          return resolved;
        }
      }

      return null;
    },
  };
}
