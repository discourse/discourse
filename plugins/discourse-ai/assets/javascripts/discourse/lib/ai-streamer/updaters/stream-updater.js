/**
 * Interface needed to implement for a streaming updater
 */
export default class StreamUpdater {
  set streaming(value) {
    throw "not implemented";
  }

  async setCooked() {
    throw "not implemented";
  }

  async setRaw() {
    throw "not implemented";
  }

  get element() {
    throw "not implemented";
  }

  get raw() {
    throw "not implemented";
  }
}
