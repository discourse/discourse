const Plugin = require("broccoli-plugin");
const sass = require("sass");
const fs = require("fs");
const concat = require("broccoli-concat");

let built = false;

class DiscourseScss extends Plugin {
  constructor(inputNodes, inputFile, options) {
    super(inputNodes, {
      ...options,
      persistentOutput: true,
    });

    this.inputFile = inputFile;
  }

  build() {
    // We could get fancy eventually and do this based on whether the css changes
    // but this is just used for tests right now.
    if (built) {
      return;
    }

    let file = this.inputPaths[0] + "/" + this.inputFile;

    let result = sass.renderSync({
      file,
      includePaths: this.inputPaths,
    });

    fs.writeFileSync(
      `${this.outputPath}/` + this.inputFile.replace(".scss", ".css"),
      result.css
    );
    built = true;
  }
}

module.exports = function scss(path, file) {
  return concat(new DiscourseScss([path], file), {
    outputFile: `assets/${file.replace(".scss", ".css")}`,
  });
};
