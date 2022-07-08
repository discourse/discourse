const mergeTrees = require("broccoli-merge-trees");
const funnel = require("broccoli-funnel");
const concat = require("broccoli-concat");
const fs = require("fs");

// Each file under `scripts/{name}.js` is run through babel, sourcemapped, and then output to `/assets/{name}.js
module.exports = function scriptsTree(app) {
  let babelAddon = app.project.findAddonByName("ember-cli-babel");
  let babelConfig = {
    babel: { sourceMaps: "inline" },
    "ember-cli-babel": { compileModules: false },
  };

  const trees = [];

  const scripts = fs
    .readdirSync("scripts", { withFileTypes: true })
    .filter((dirent) => dirent.isFile());

  for (let script of scripts) {
    let source = funnel(`scripts`, {
      files: [script.name],
      destDir: "scripts",
    });

    // Babel will append a base64 sourcemap to the file
    let transpiled = babelAddon.transpileTree(source, babelConfig);

    // We don't actually need to concat any source files... but this will move the base64
    // source map into its own file
    let transpiledWithDecodedSourcemap = concat(transpiled, {
      outputFile: `assets/${script.name}`,
    });

    trees.push(transpiledWithDecodedSourcemap);
  }

  return mergeTrees(trees);
};
