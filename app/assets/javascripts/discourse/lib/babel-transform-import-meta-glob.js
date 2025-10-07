const { globSync } = require("glob");
const { dirname, join } = require("path");

// https://astexplorer.net/#/gist/14696755417f9d41c8c2bd72c187b0da/41a903d14d860270fa4eefab69c8ae8934971cdc
module.exports = function ({ types: t }) {
  let program;

  const handleEager = (path, files) => {
    let identifiers = [];
    // create the imports
    const imports = files.map((globPath, idx) => {
      const name = `_w${idx}`;
      const identifier = t.identifier(name);
      identifiers.push({ name, globPath: globPath.importFile });
      const importNamespaceSpecifier = t.importNamespaceSpecifier(identifier);
      return t.importDeclaration(
        [importNamespaceSpecifier],
        t.stringLiteral(`./${globPath.importFile}`)
      );
    });
    program.unshiftContainer("body", imports);

    const newObj = identifiers.map(({ name, globPath }) => {
      return t.objectProperty(
        t.stringLiteral(`./${globPath}`),
        t.identifier(name)
      );
    });
    path.replaceWith(t.objectExpression(newObj));
  };
  return {
    name: "ember-meta-glob", // not required
    visitor: {
      Program(path) {
        // keep a reference to the Program
        program = path;
      },
      CallExpression(path, state) {
        const { node } = path;
        // return early if it is not the import we are looking for
        if (
          node.callee.object?.meta?.name !== "import" ||
          node.callee.object.property?.name !== "meta" ||
          node.callee.property?.name !== "glob"
        ) {
          return;
        }

        let cwd;

        if (state.filename.includes(".embroider")) {
          cwd = dirname(state.filename);
        } else {
          cwd = dirname(
            [
              ...state.cwd.split("/"),
              "app",
              ...state.filename
                .slice(state.cwd.length + 1)
                .split("/")
                .slice(1),
            ].join("/")
          );
        }

        // get the files from the file system
        const pathName = node.arguments[0].value;
        let foundFiles = globSync(pathName, {
          ignore: "node_modules/**",
          nodir: true,
          cwd,
        });

        // dedupe the files and remove the suffix
        const files = [];
        foundFiles.forEach((file) => {
          const regex = new RegExp(/.[tjhbcs]s?$/g);
          if (!regex.test(file)) {
            return;
          }
          const withoutSuffix = file.replace(/\.\w+$/, "");
          if (files.find((f) => f.importFile === withoutSuffix)) {
            return;
          }

          // can we discover this!?
          let appName = "discourse";

          // prevent finding "yourself" in a import.meta.glob
          if (
            join(cwd, withoutSuffix) ===
            state.filename
              .replace(`${appName}/${appName}`, `${appName}/app`)
              .replace(/\.\w+$/, "")
          ) {
            return;
          }

          files.push({ sourceFile: file, importFile: withoutSuffix });
        });

        files.sort((a, b) => a.sourceFile.localeCompare(b.sourceFile));

        const isEager =
          (node.arguments[1] &&
            node.arguments[1].properties[0].key.name === "eager" &&
            node.arguments[1].properties[0].value.value) ||
          false;

        // branch off if using the eager strategy
        if (isEager) {
          handleEager(path, files);
          return;
        }

        // replace the glob import and a lazy import of all of the files found
        const newObj = files.map((file) => {
          return t.objectProperty(
            t.stringLiteral(`./${file.sourceFile}`),
            t.arrowFunctionExpression(
              [],
              t.callExpression(t.identifier("require"), [
                t.stringLiteral(file.importFile),
              ])
            )
          );
        });

        path.replaceWith(t.objectExpression(newObj));
      },
    },
  };
};
