export default function discourseIndexSearch() {
  return {
    name: "discourse-index-search",
    async resolveId(source, context) {
      if (source.match(/\.\w+$/) || source.match(/\/index$/)) {
        // Already has an extension or is an index
        return null;
      }

      return (
        (await this.resolve(source, context)) ||
        (await this.resolve(`${source}/index`, context))
      );
    },
  };
}
