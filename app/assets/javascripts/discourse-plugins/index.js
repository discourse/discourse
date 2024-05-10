"use strict";

const path = require("path");
const WatchedDir = require("broccoli-source").WatchedDir;
const Funnel = require("broccoli-funnel");
const mergeTrees = require("broccoli-merge-trees");
const fs = require("fs");
const concat = require("broccoli-concat");
const RawHandlebarsCompiler = require("discourse-hbr/raw-handlebars-compiler");
const DiscoursePluginColocatedTemplateProcessor = require("./colocated-template-compiler");
const EmberApp = require("ember-cli/lib/broccoli/ember-app");

function fixLegacyExtensions(tree) {
  return new Funnel(tree, {
    getDestinationPath: function (relativePath) {
      if (relativePath.endsWith(".es6")) {
        return relativePath.slice(0, -4);
      } else if (relativePath.endsWith(".raw.hbs")) {
        relativePath = relativePath.replace(".raw.hbs", ".hbr");
      }

      if (relativePath.endsWith(".hbr")) {
        if (relativePath.includes("/templates/")) {
          relativePath = relativePath.replace("/templates/", "/raw-templates/");
        } else if (relativePath.includes("/connectors/")) {
          relativePath = relativePath.replace(
            "/connectors/",
            "/raw-templates/connectors/"
          );
        }
      }

      return relativePath;
    },
  });
}

const COLOCATED_CONNECTOR_REGEX =
  /^(?<prefix>.*)\/connectors\/(?<outlet>[^\/]+)\/(?<name>[^\/\.]+)\.(?<extension>.+)$/;

// Having connector templates and js in the same directory causes a clash
// when outputting es6 modules. This shim separates colocated connectors
// into separate js / template locations.
function unColocateConnectors(tree) {
  return new Funnel(tree, {
    getDestinationPath: function (relativePath) {
      const match = relativePath.match(COLOCATED_CONNECTOR_REGEX);
      if (
        match &&
        match.groups.extension === "hbs" &&
        match.groups.prefix.split("/").pop() !== "templates"
      ) {
        const { prefix, outlet, name } = match.groups;
        return `${prefix}/templates/connectors/${outlet}/${name}.hbs`;
      }
      if (
        match &&
        match.groups.extension === "js" &&
        match.groups.prefix.split("/").pop() === "templates"
      ) {
        // Some plugins are colocating connector JS under `/templates`
        const { prefix, outlet, name } = match.groups;
        const newPrefix = prefix.slice(0, -"/templates".length);
        return `${newPrefix}/connectors/${outlet}/${name}.js`;
      }
      return relativePath;
    },
  });
}

function namespaceModules(tree, pluginName) {
  return new Funnel(tree, {
    getDestinationPath: function (relativePath) {
      return `discourse/plugins/${pluginName}/${relativePath}`;
    },
  });
}

function parsePluginName(pluginRbPath) {
  const pluginRb = fs.readFileSync(pluginRbPath, "utf8");
  // Match parsing logic in `lib/plugin/metadata.rb`
  for (const line of pluginRb.split("\n")) {
    if (line.startsWith("#")) {
      const [attribute, value] = line.slice(1).split(":", 2);
      if (attribute.trim() === "name") {
        return value.trim();
      }
    }
  }
  throw new Error(
    `Unable to parse plugin name from metadata in ${pluginRbPath}`
  );
}

module.exports = {
  name: require("./package").name,

  options: {
    babel: {
      plugins: [require.resolve("deprecation-silencer")],
    },

    "ember-cli-babel": {
      throwUnlessParallelizable: true,
    },

    "ember-this-fallback": {
      enableLogging: false,
    },
  },

  pluginInfos() {
    const root = path.resolve("../../../../plugins");
    const pluginDirectories = fs
      .readdirSync(root, { withFileTypes: true })
      .filter(
        (dirent) =>
          (dirent.isDirectory() || dirent.isSymbolicLink()) &&
          !dirent.name.startsWith(".") &&
          fs.existsSync(path.resolve(root, dirent.name, "plugin.rb"))
      );

    return pluginDirectories.map((directory) => {
      const directoryName = directory.name;
      const pluginName = parsePluginName(
        path.resolve(root, directoryName, "plugin.rb")
      );
      const jsDirectory = path.resolve(
        root,
        directoryName,
        "assets/javascripts"
      );
      const adminJsDirectory = path.resolve(
        root,
        directoryName,
        "admin/assets/javascripts"
      );
      const testDirectory = path.resolve(
        root,
        directoryName,
        "test/javascripts"
      );
      const configDirectory = path.resolve(root, directoryName, "config");
      const hasJs = fs.existsSync(jsDirectory);
      const hasAdminJs = fs.existsSync(adminJsDirectory);
      const hasTests = fs.existsSync(testDirectory);
      const hasConfig = fs.existsSync(configDirectory);
      return {
        pluginName,
        directoryName,
        jsDirectory,
        adminJsDirectory,
        testDirectory,
        configDirectory,
        hasJs,
        hasAdminJs,
        hasTests,
        hasConfig,
      };
    });
  },

  generatePluginsTree(withTests) {
    if (!this.shouldLoadPlugins()) {
      return mergeTrees([]);
    }
    const trees = [
      this._generatePluginAppTree(),
      this._generatePluginAdminTree(),
    ];
    if (withTests) {
      trees.push(this._generatePluginTestTree());
    }
    return mergeTrees(trees);
  },

  _generatePluginAppTree() {
    const trees = this.pluginInfos()
      .filter((p) => p.hasJs)
      .map(({ pluginName, directoryName, jsDirectory }) =>
        this._buildAppTree({
          directory: jsDirectory,
          pluginName,
          outputFile: `assets/plugins/${directoryName}.js`,
        })
      );
    return mergeTrees(trees);
  },

  _generatePluginAdminTree() {
    const trees = this.pluginInfos()
      .filter((p) => p.hasAdminJs)
      .map(({ pluginName, directoryName, adminJsDirectory }) =>
        this._buildAppTree({
          directory: adminJsDirectory,
          pluginName,
          outputFile: `assets/plugins/${directoryName}_admin.js`,
        })
      );
    return mergeTrees(trees);
  },

  _buildAppTree({ directory, pluginName, outputFile }) {
    let tree = new WatchedDir(directory);

    tree = fixLegacyExtensions(tree);
    tree = unColocateConnectors(tree);
    tree = namespaceModules(tree, pluginName);

    tree = RawHandlebarsCompiler(tree);

    const colocateBase = `discourse/plugins/${pluginName}`;
    tree = new DiscoursePluginColocatedTemplateProcessor(
      tree,
      `${colocateBase}/discourse`
    );
    tree = new DiscoursePluginColocatedTemplateProcessor(
      tree,
      `${colocateBase}/admin`
    );
    tree = this.compileTemplates(tree);

    tree = this.processedAddonJsFiles(tree);

    return concat(mergeTrees([tree]), {
      inputFiles: ["**/*.js"],
      outputFile,
      allowNone: true,
    });
  },

  _generatePluginTestTree() {
    const trees = this.pluginInfos()
      .filter((p) => p.hasTests)
      .map(({ pluginName, directoryName, testDirectory }) => {
        let tree = new WatchedDir(testDirectory);

        tree = fixLegacyExtensions(tree);
        tree = namespaceModules(tree, pluginName);
        tree = this.processedAddonJsFiles(tree);

        return concat(mergeTrees([tree]), {
          inputFiles: ["**/*.js"],
          outputFile: `assets/plugins/test/${directoryName}_tests.js`,
          allowNone: true,
        });
      });
    return mergeTrees(trees);
  },

  shouldCompileTemplates() {
    // The base Addon implementation checks for template
    // files in the addon directories. We need to override that
    // check so that the template compiler always runs.
    return true;
  },

  // Matches logic from GlobalSetting.load_plugins? in the ruby app
  shouldLoadPlugins() {
    if (process.env.LOAD_PLUGINS === "1") {
      return true;
    } else if (process.env.LOAD_PLUGINS === "0") {
      return false;
    } else if (EmberApp.env() === "test") {
      return false;
    } else {
      return true;
    }
  },

  pluginScriptTags(config) {
    const scripts = [];

    const pluginInfos = this.pluginInfos();

    for (const {
      pluginName,
      directoryName,
      hasJs,
      hasAdminJs,
    } of pluginInfos) {
      if (hasJs) {
        scripts.push({
          src: `plugins/${directoryName}.js`,
          name: pluginName,
        });
      }

      if (fs.existsSync(`../plugins/${directoryName}_extras.js.erb`)) {
        scripts.push({
          src: `plugins/${directoryName}_extras.js`,
          name: pluginName,
        });
      }

      if (hasAdminJs) {
        scripts.push({
          src: `plugins/${directoryName}_admin.js`,
          name: pluginName,
        });
      }
    }

    return scripts
      .map(
        ({ src, name }) =>
          `<script src="${config.rootURL}assets/${src}" data-discourse-plugin="${name}"></script>`
      )
      .join("\n");
  },

  pluginTestScriptTags(config) {
    return this.pluginInfos()
      .filter(({ hasTests }) => hasTests)
      .map(
        ({ directoryName, pluginName }) =>
          `<script src="${config.rootURL}assets/plugins/test/${directoryName}_tests.js" data-discourse-plugin="${pluginName}"></script>`
      )
      .join("\n");
  },

  contentFor(type, config) {
    if (!this.shouldLoadPlugins()) {
      return;
    }

    switch (type) {
      case "test-plugin-js":
        return this.pluginScriptTags(config);

      case "test-plugin-tests-js":
        return this.pluginTestScriptTags(config);

      case "test-plugin-css":
        return `<link rel="stylesheet" href="${config.rootURL}bootstrap/plugin-css-for-tests.css" data-discourse-plugin="_all" />`;
    }
  },
};
