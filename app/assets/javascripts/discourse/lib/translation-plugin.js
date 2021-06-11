const Plugin = require("broccoli-plugin");
const Yaml = require("js-yaml");
const fs = require("fs");
const concat = require("broccoli-concat");
const mergeTrees = require("broccoli-merge-trees");

let built = false;

class TranslationPlugin extends Plugin {
  constructor(inputNodes, inputFile, options) {
    super(inputNodes, {
      ...options,
      persistentOutput: true,
    });

    this.inputFile = inputFile;
  }

  build() {
    // We could get fancy eventually and do this based on whether the yaml
    // or vendor files change but in practice we shouldn't need exact up to date
    // translations in admin.
    if (built) {
      return;
    }

    let file = this.inputPaths[0] + "/" + this.inputFile;

    let yaml = fs.readFileSync(file, { encoding: "UTF-8" });
    let parsed = Yaml.load(yaml);

    let extras = {
      en: {
        admin: parsed.en.admin_js.admin,
      },
    };

    delete parsed.en.admin_js;
    delete parsed.en.wizard_js;

    let contents = `
      I18n.locale = 'en';
      I18n.translations = ${JSON.stringify(parsed)};
      I18n.extras = ${JSON.stringify(extras)};
      I18n._compiledMFs = {};
    `;

    fs.writeFileSync(
      `${this.outputPath}/` + this.inputFile.replace(".yml", ".js"),
      contents
    );
    built = true;
  }
}

module.exports = function translatePlugin(...params) {
  return new TranslationPlugin(...params);
};

module.exports.createI18nTree = function (discourseRoot, vendorJs) {
  let en = new TranslationPlugin(
    [discourseRoot + "/config/locales"],
    "client.en.yml"
  );

  return concat(
    mergeTrees([
      vendorJs,
      discourseRoot + "/app/assets/javascripts/locales",
      discourseRoot + "/lib/javascripts",
      en,
    ]),
    {
      inputFiles: [
        "i18n.js",
        "moment.js",
        "moment-timezone-with-data.js",
        "messageformat-lookup.js",
        "client.en.js",
      ],
      headerFiles: [
        "i18n.js",
        "moment.js",
        "moment-timezone-with-data.js",
        "messageformat-lookup.js",
      ],
      footerFiles: ["client.en.js"],
      outputFile: `assets/test-i18n.js`,
    }
  );
};

module.exports.TranslationPlugin = TranslationPlugin;
