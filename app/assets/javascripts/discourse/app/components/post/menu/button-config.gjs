import { bind } from "discourse-common/utils/decorators";

export default class PostMenuButtonConfig {
  #Component;
  #delegateShouldRenderToTemplate;
  #alwaysShow;
  #extraControls;
  #key;
  #position;
  #shouldRender;
  #showLabel;

  constructor({ key, Component, position }) {
    this.#Component = Component;
    this.#alwaysShow = Component.alwaysShow;
    this.#delegateShouldRenderToTemplate =
      Component.delegateShouldRenderToTemplate;
    this.#extraControls = Component.extraControls;
    this.#key = key;
    this.#position = position;
    this.#shouldRender = Component.shouldRender;
    this.#showLabel = Component.showLabel;
  }

  get Component() {
    return this.#Component;
  }

  @bind
  alwaysShow(args) {
    if (typeof this.#alwaysShow === "function") {
      return this.#alwaysShow(args);
    }

    return this.#alwaysShow ?? false;
  }

  get delegateShouldRenderToTemplate() {
    return this.#delegateShouldRenderToTemplate ?? false;
  }

  get extraControls() {
    return this.#extraControls;
  }

  get key() {
    return this.#key;
  }

  get position() {
    return this.#position;
  }

  @bind
  shouldRender(args) {
    if (typeof this.#shouldRender === "function") {
      return this.#shouldRender(args);
    }

    return this.#shouldRender ?? true;
  }

  @bind
  showLabel(args) {
    if (typeof this.#showLabel === "function") {
      return this.#showLabel(args);
    }

    return this.#showLabel ?? false;
  }
}
