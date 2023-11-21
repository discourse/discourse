import { Addon } from "@embroider/addon-dev/rollup";
import exportPluginFeatures from "./export-plugin-features.js";

export default class Plugin {
  #addon;

  constructor({ srcDir = "src", destDir = "dist" } = {}) {
    this.#addon = new Addon({ srcDir, destDir });
  }

  publicEntrypoints(patterns) {
    return this.#addon.publicEntrypoints(patterns);
  }

  exportPluginFeatures() {
    return exportPluginFeatures();
  }

  dependencies() {
    return this.#addon.dependencies();
  }

  gjs() {
    return this.#addon.gjs();
  }

  output() {
    return this.#addon.output();
  }

  clean(options) {
    return this.#addon.clean(options);
  }
}
