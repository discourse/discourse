// https://astexplorer.net/#/gist/14696755417f9d41c8c2bd72c187b0da/41a903d14d860270fa4eefab69c8ae8934971cdc
export default function ({ types: t }) {
  return {
    visitor: {
      ImportDeclaration(path) {
        const moduleName = path.node.source.value;
        if (
          /^(admin|select-kit|float-kit|dialog-holder)\//.test(moduleName) ||
          moduleName.startsWith("truth-helpers")
        ) {
          path.node.source = t.stringLiteral(`discourse/${moduleName}`);
        }
      },
    },
  };
}
