import { Addon } from "@embroider/addon-dev/rollup";
import exportPluginFeatures from "./export-plugin-features.js";

export default class Plugin {
  #addon;
  #srcDir;
  #destDir;

  constructor({ srcDir = "src", destDir = "dist" } = {}) {
    this.#addon = new Addon({ srcDir, destDir });
    this.#srcDir = srcDir;
    this.#destDir = destDir;
  }

  exportPluginFeatures() {
    return exportPluginFeatures({
      srcDir: this.#srcDir,
      destDir: this.#destDir,
    });
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
