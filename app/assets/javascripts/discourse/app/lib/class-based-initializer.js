import { setOwner } from "@ember/owner";

export default class ClassBasedInitializer {
  static initialize(appInstance) {
    this.instance = new this(appInstance);
    this.instance.initialize(appInstance);
  }

  static teardown() {
    this.instance.willDestroy?.();
    this.instance = null;
  }

  constructor(appInstance) {
    setOwner(this, appInstance);
  }
}
