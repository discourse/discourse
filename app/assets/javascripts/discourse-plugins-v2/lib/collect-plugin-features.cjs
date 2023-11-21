const { readJsonSync, writeJsonSync } = require("fs-extra");
const path = require("path");

class PluginFeature {
  #entries = [];

  add(dep, entry) {
    this.#entries.push(`${dep}/${entry.slice(2)}`);
  }

  get content() {
    let content = "";

    content += 'import { importSync } from "@embroider/macros";\n';
    content += "\n";
    content += "export default [\n";

    for (const entry of this.#entries) {
      const quoted = JSON.stringify(entry);
      content += "  {\n";
      content += `    name: ${quoted},\n`;
      content += `    module: importSync(${quoted}),\n`;
      content += "  },\n";
    }

    content += "];\n";

    return content;
  }
}

class Connector extends PluginFeature {
  #name;
  #entryName;

  constructor(name) {
    super();
    this.#name = name;
    this.#entryName = `./connectors/${name}`;
  }

  get fileName() {
    return `connectors/${this.#name}.js`;
  }

  get entryName() {
    return this.#entryName;
  }

  process(dep, entries) {
    const entry = entries[this.#entryName];

    if (entry) {
      this.add(dep, this.#entryName);
    }
  }
}

class MarkdownFeatures extends PluginFeature {
  get fileName() {
    return "markdown-features.js";
  }

  get entryName() {
    return "./markdown-features";
  }

  process(dep, entries) {
    for (const entry of Object.keys(entries)) {
      if (entry.startsWith("./markdown-features/")) {
        this.add(dep, entry);
      }
    }
  }
}

function isPlugin(packageJson) {
  return packageJson.keywords?.includes("discourse-plugin");
}

function collectPluginFeatures({
  connectors = [],
  markdownFeatures = true,
} = {}) {
  return {
    name: "collect-plugin-features",
    buildStart() {
      const packageJson = readJsonSync("package.json");

      const dependencies = packageJson.dependencies || [];
      const originalExports = packageJson.exports;
      const exports = {};

      const features = [];

      for (const name of connectors) {
        features.push(new Connector(name));
      }

      if (markdownFeatures) {
        features.push(new MarkdownFeatures());
      }

      for (const dependency of Object.keys(dependencies)) {
        const depPath = require.resolve(path.join(dependency, "package.json"));

        const depJson = readJsonSync(depPath);

        this.addWatchFile(depPath);

        if (isPlugin(depJson) && depJson.exports) {
          for (const feature of features) {
            feature.process(dependency, depJson.exports);
          }
        }
      }

      for (const feature of features) {
        exports[feature.entryName] = `./dist/${feature.fileName}`;
        this.emitFile({
          type: "prebuilt-chunk",
          fileName: feature.fileName,
          code: feature.content,
          exports: ["default"],
        });
      }

      const hasChanges =
        JSON.stringify(originalExports) !== JSON.stringify(exports);

      if (hasChanges) {
        packageJson.exports = exports;
        writeJsonSync("package.json", packageJson, { spaces: 2 });
      }
    },
  };
}

module.exports = {
  collectPluginFeatures,
};
