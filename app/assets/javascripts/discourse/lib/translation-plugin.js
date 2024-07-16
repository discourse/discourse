const Plugin = require("broccoli-plugin");
const Yaml = require("js-yaml");
const fs = require("fs");
const concat = require("broccoli-concat");
const mergeTrees = require("broccoli-merge-trees");
const MessageFormat = require("@messageformat/core");
const deepmerge = require("deepmerge");
const glob = require("glob");
const { shouldLoadPlugins } = require("discourse-plugins");

let built = false;

class TranslationPlugin extends Plugin {
  constructor(inputNodes, inputFile, options) {
    super(inputNodes, {
      ...options,
      persistentOutput: true,
    });

    this.inputFile = inputFile;
  }

  replaceMF(formats, input, path = []) {
    if (!input) {
      return;
    }

    Object.keys(input).forEach((key) => {
      let value = input[key];

      let subpath = path.concat(key);
      if (typeof value === "object") {
        this.replaceMF(formats, value, subpath);
      } else if (key.endsWith("_MF")) {
        // omit locale.js
        let mfPath = subpath.slice(2).join(".");
        formats[mfPath] = this.mf.compile(value);
      }
    });
  }

  build() {
    // We could get fancy eventually and do this based on whether the yaml
    // or vendor files change but in practice we shouldn't need exact up to date
    // translations in admin.
    if (built) {
      return;
    }

    let parsed = {};

    this.inputPaths.forEach((path) => {
      let file = path + "/" + this.inputFile;
      let yaml = fs.readFileSync(file, { encoding: "UTF-8" });
      let loaded = Yaml.load(yaml, { json: true });
      parsed = deepmerge(parsed, loaded);
    });

    let extras = {
      en: {
        admin: parsed.en.admin_js.admin,
        wizard: parsed.en.wizard_js.wizard,
      },
    };

    delete parsed.en.admin_js;
    delete parsed.en.wizard_js;

    let formats = {};
    this.mf = new MessageFormat("en");
    this.replaceMF(formats, parsed);
    this.replaceMF(formats, extras);

    formats = Object.entries(formats).map(([k, v]) => `"${k}": ${v}`);

    let contents = `
      (function() {
        I18n.locale = 'en';
        I18n.translations = ${JSON.stringify(parsed)};
        I18n.extras = ${JSON.stringify(extras)};

        const Messages = require("@messageformat/runtime/messages").default;
        const { number, plural, select } = require("@messageformat/runtime");
        const { en } = require("@messageformat/runtime/lib/cardinals");
        const msgData = { en: { ${formats.join(",\n")} } };
        const messages = new Messages(msgData, "en");
        messages.defaultLocale = "en";
        I18n._mfMessages = messages;
      })()
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
  let translations = [discourseRoot + "/config/locales"];

  if (shouldLoadPlugins()) {
    translations = translations.concat(
      glob
        .sync(discourseRoot + "/plugins/*/config/locales/client.en.yml")
        .map((f) => f.replace(/\/client\.en\.yml$/, ""))
    );
  }

  let en = new TranslationPlugin(translations, "client.en.yml");

  return concat(
    mergeTrees([
      vendorJs,
      discourseRoot + "/app/assets/javascripts/locales",
      en,
    ]),
    {
      inputFiles: [
        "i18n.js",
        "moment.js",
        "moment-timezone-with-data.js",
        "client.en.js",
      ],
      headerFiles: ["i18n.js", "moment.js", "moment-timezone-with-data.js"],
      footerFiles: ["client.en.js"],
      outputFile: `assets/test-i18n.js`,
    }
  );
};

module.exports.TranslationPlugin = TranslationPlugin;
