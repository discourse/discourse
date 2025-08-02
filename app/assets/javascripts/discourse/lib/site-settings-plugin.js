const Plugin = require("broccoli-plugin");
const Yaml = require("js-yaml");
const fs = require("fs");
const concat = require("broccoli-concat");
const mergeTrees = require("broccoli-merge-trees");
const deepmerge = require("deepmerge");
const glob = require("glob");
const { shouldLoadPlugins } = require("discourse-plugins");

let built = false;

class SiteSettingsPlugin extends Plugin {
  constructor(inputNodes, inputFile, options) {
    super(inputNodes, {
      ...options,
      persistentOutput: true,
    });
  }

  build() {
    if (built) {
      return;
    }

    let parsed = {};

    this.inputPaths.forEach((path) => {
      let inputFile;
      if (path.includes("plugins")) {
        inputFile = "settings.yml";
      } else {
        inputFile = "site_settings.yml";
      }
      const file = path + "/" + inputFile;
      let yaml;
      try {
        yaml = fs.readFileSync(file, { encoding: "UTF-8" });
      } catch {
        // the plugin does not have a config file, go to the next file
        return;
      }
      const loaded = Yaml.load(yaml, { json: true });
      parsed = deepmerge(parsed, loaded);
    });

    let clientSettings = {};
    // eslint-disable-next-line no-unused-vars
    for (const [category, settings] of Object.entries(parsed)) {
      for (const [setting, details] of Object.entries(settings)) {
        if (details.client) {
          clientSettings[setting] = details.default;
        }
      }
    }
    const contents = `var CLIENT_SITE_SETTINGS_WITH_DEFAULTS  = ${JSON.stringify(
      clientSettings
    )}`;

    fs.writeFileSync(`${this.outputPath}/` + "settings_out.js", contents);
    built = true;
  }
}

module.exports = function siteSettingsPlugin(...params) {
  return new SiteSettingsPlugin(...params);
};

module.exports.parsePluginClientSettings = function (
  discourseRoot,
  vendorJs,
  app
) {
  let settings = [discourseRoot + "/config"];

  if (shouldLoadPlugins()) {
    const pluginInfos = app.project
      .findAddonByName("discourse-plugins")
      .pluginInfos();
    pluginInfos.forEach(({ hasConfig, configDirectory }) => {
      if (hasConfig) {
        settings = settings.concat(glob.sync(configDirectory));
      }
    });
  }

  const loadedSettings = new SiteSettingsPlugin(settings, "site_settings.yml");

  return concat(mergeTrees([loadedSettings]), {
    inputFiles: [],
    headerFiles: [],
    footerFiles: [],
    outputFile: `assets/test-site-settings.js`,
  });
};

module.exports.SiteSettingsPlugin = SiteSettingsPlugin;
