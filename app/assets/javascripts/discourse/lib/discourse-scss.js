const Plugin = require("broccoli-plugin");
const sass = require("sass");
const fs = require("fs");
const concat = require("broccoli-concat");

let builtSet = new Set();

class DiscourseScss extends Plugin {
  constructor(inputNodes, inputFile, options) {
    super(inputNodes, {
      ...options,
      persistentOutput: true,
    });

    this.inputFile = inputFile;
  }

  build() {
    let file = this.inputPaths[0] + "/" + this.inputFile;

    // We could get fancy eventually and do this based on whether the css changes
    // but this is just used for tests right now.
    if (builtSet.has(file)) {
      return;
    }

    let deprecationCount = 0;
    let result = sass.renderSync({
      file,
      includePaths: this.inputPaths,
      verbose: true, // call warn() for all deprecations
      logger: {
        warn(message, options) {
          if (options.deprecation) {
            deprecationCount += 1;
          } else {
            // eslint-disable-next-line no-console
            console.warn(`\nWARNING: ${message}`);
          }
        },
      },
    });
    if (deprecationCount > 0) {
      // eslint-disable-next-line no-console
      console.warn(
        `\nWARNING: ${deprecationCount} deprecations encountered while compiling scss. (we cannot correct these until the Ruby SCSS pipeline is updated)`
      );
    }

    fs.writeFileSync(
      `${this.outputPath}/` + this.inputFile.replace(".scss", ".css"),
      result.css
    );

    builtSet.add(file);
  }
}

module.exports = function scss(path, file) {
  return concat(new DiscourseScss([path], file), {
    outputFile: `assets/${file.replace(".scss", ".css")}`,
  });
};
