const roots = [
  "./app",
  "../discourse-common/addon",
  "../admin/addon",
  "../select-kit/addon",
  "../float-kit/addon",
  "../dialog-holder/addon",
];
const compatPattern = /@embroider\/virtual\/(?<type>[^\/]+)\/(?<rest>.*)/;
export default function customInvokableResolver() {
  return {
    name: "discourse-custom-invokable-resolver",

    async resolveId(source, importer, options) {
      if (!source.startsWith("@embroider/virtual/")) {
        return;
      }
      const resolved = await this.resolve(source, process.cwd(), options);
      if (resolved) {
        // console.log(resolved, source);
        return resolved;
      } else {
        let match = compatPattern.exec(source);
        let { type: requestedType, rest } = match.groups;
        const types =
          requestedType === "ambiguous"
            ? ["components", "helpers"]
            : [requestedType];

        for (let type of types) {
          for (let root of roots) {
            const resolved = await this.resolve(
              `/${root}/${type}/${rest}`,
              null,
              options
            );
            if (resolved) {
              return resolved;
            }
          }
        }
        console.error("no resolve for", source);
      }
    },
  };
}
