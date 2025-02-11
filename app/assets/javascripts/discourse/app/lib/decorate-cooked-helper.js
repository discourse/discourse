import { getOwner, setOwner } from "@ember/owner";

export default class DecorateCookedHelper {
  #renderGlimmerInfos = [];

  constructor({ owner, diffHtmlMode }) {
    this.diffHtmlMode = diffHtmlMode;
    setOwner(this, owner);
  }

  get #renderGlimmerService() {
    return getOwner(this).lookup("service:render-glimmer");
  }

  renderGlimmer(element, component, data) {
    if (this.diffHtmlMode) {
      throw "renderGlimmer is not supported when the experimental enable_diffhtml_preview site setting is enabled. Disable enable_diffhtml_preview to continue.";
    }

    const info = {
      element,
      component,
      data,
    };
    this.#renderGlimmerInfos.push(info);
    this.#renderGlimmerService.add(info);
  }

  /**
   *
   */
  getModel() {
    return null;
  }

  teardown() {
    for (const info of this.#renderGlimmerInfos) {
      this.#renderGlimmerService.remove(info);
    }
  }
}
