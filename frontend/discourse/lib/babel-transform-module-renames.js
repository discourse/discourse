// https://astexplorer.net/#/gist/14696755417f9d41c8c2bd72c187b0da/41a903d14d860270fa4eefab69c8ae8934971cdc
export default function ({ types: t }) {
  return {
    visitor: {
      ImportDeclaration(path) {
        const moduleName = path.node.source.value;
        if (moduleName.startsWith("admin/")) {
          path.node.source = t.stringLiteral(`discourse/${moduleName}`);
        }

        if (moduleName.startsWith(".") && moduleName.match(/\.g?js$/)) {
          path.node.source = t.stringLiteral(moduleName.replace(/\.g?js$/, ""));
        }
      },
    },
  };
}
