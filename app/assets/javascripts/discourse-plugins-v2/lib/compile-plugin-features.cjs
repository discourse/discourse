const { readdirSync } = require("fs");
const {
  emptyDirSync,
  readJsonSync,
  writeJsonSync,
  outputFileSync,
} = require("fs-extra");
const path = require("path");

class PluginFeature {
  #entries = new Map();

  add(dep, entry) {
    const module = `${dep}/${entry.slice(2)}`;
    const identifier = this.#identifierFor(module);
    const quoted = JSON.stringify(module);
    this.#entries.set(identifier, quoted);
  }

  get content() {
    if (this.#entries.size === 0) {
      return "export default [];\n";
    }

    let content = "";

    for (const [identifier, quoted] of this.#entries) {
      content += `import * as ${identifier} from ${quoted};\n`;
    }

    content += "\n";
    content += "export default [\n";

    for (const [identifier, quoted] of this.#entries) {
      content += "  {\n";
      content += `    name: ${quoted},\n`;
      content += `    module: ${identifier},\n`;
      content += "  },\n";
    }

    content += "];\n";

    return content;
  }

  #identifierFor(module) {
    const base = module.replaceAll(/[^a-z0-9]+/gi, "_");
    let i = 0;
    let identifier = `$${base}`;

    while (this.#entries.has(identifier)) {
      identifier = `$${base}_${++i}`;
    }

    return identifier;
  }
}

class NamedPluginFeature extends PluginFeature {
  #namespace;
  #name;
  #entryName;

  constructor(namespace, name) {
    super();
    this.#namespace = namespace;
    this.#name = name;
    this.#entryName = `./${namespace}/${name}`;
  }

  get fileName() {
    return `${this.#namespace}/${this.#name}.js`;
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

function compilePluginFeatures(
  pluginsDir,
  { connectors = [], events = [], routeMaps = [], markdownFeatures = true } = {}
) {
  return {
    name: "collect-plugin-features",
    buildStart() {
      emptyDirSync("./src");

      const packageJson = readJsonSync("package.json");
      const originalExports = packageJson.exports;
      const exports = {};

      const features = [];

      for (const name of connectors) {
        features.push(new NamedPluginFeature("connectors", name));
      }

      for (const name of events) {
        features.push(new NamedPluginFeature("events", name));
      }

      for (const name of routeMaps) {
        features.push(new NamedPluginFeature("route-maps", name));
      }

      if (markdownFeatures) {
        features.push(new MarkdownFeatures());
      }

      const pluginsDirEntries = readdirSync(pluginsDir, {
        withFileTypes: true,
      });

      for (const entry of pluginsDirEntries) {
        if (!entry.isDirectory()) {
          continue;
        }

        let depPath;
        let depJson;

        try {
          depPath = path.join(pluginsDir, entry.name, "package.json");
          depJson = readJsonSync(depPath);
        } catch {
          continue;
        }

        if (isPlugin(depJson)) {
          this.addWatchFile(depPath);

          if (depJson.exports) {
            for (const feature of features) {
              feature.process(depJson.name, depJson.exports);
            }
          }
        }
      }

      for (const feature of features) {
        exports[feature.entryName] = `./dist/${feature.fileName}`;

        outputFileSync(`./src/${feature.fileName}`, feature.content, {
          encoding: "utf8",
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
  compilePluginFeatures,
};
