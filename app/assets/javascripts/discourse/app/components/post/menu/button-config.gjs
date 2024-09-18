import { bind } from "discourse-common/utils/decorators";

export default class PostMenuButtonConfig {
  #Component;
  #alwaysShow;
  #extraControls;
  #key;
  #position;
  #shouldRender;
  #showLabel;

  constructor(config) {
    this.#Component = config.Component;
    this.#alwaysShow = config.alwaysShow;
    this.#extraControls = config.extraControls;
    this.#key = config.key;
    this.#position = config.position;
    this.#shouldRender = config.shouldRender;
    this.#showLabel = config.showLabel;
  }

  @bind
  alwaysShow(args) {
    if (typeof this.#alwaysShow === "function") {
      return this.#alwaysShow(args);
    }

    return this.#alwaysShow ?? false;
  }

  @bind
  showLabel(args) {
    if (typeof this.#showLabel === "function") {
      return this.#showLabel(args);
    }

    return this.#showLabel ?? false;
  }

  @bind
  shouldRender(args) {
    if (typeof this.#shouldRender === "function") {
      return this.#shouldRender(args);
    }

    return this.#shouldRender ?? true;
  }

  get key() {
    return this.#key;
  }

  get Component() {
    return this.#Component;
  }

  get position() {
    return this.#position;
  }

  get extraControls() {
    return this.#extraControls;
  }
}
