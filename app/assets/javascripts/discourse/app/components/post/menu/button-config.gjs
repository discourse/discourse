import { helperContext } from "discourse-common/lib/helpers";
import { bind } from "discourse-common/utils/decorators";

export default class PostMenuButtonConfig {
  #Component;
  #apiAdded;
  #key;
  #owner;
  #position;
  #replacementMap;
  #showLabel;

  constructor({
    key,
    Component,
    apiAdded,
    owner,
    position,
    replacementMap,
    showLabel,
  }) {
    this.#Component = Component;
    this.#apiAdded = apiAdded;
    this.#key = key;
    this.#owner = owner;
    this.#position = position;
    this.#replacementMap = replacementMap;
    this.#showLabel = showLabel;
  }

  get Component() {
    return this.#Component;
  }

  get apiAdded() {
    return this.#apiAdded;
  }

  @bind
  hidden(args) {
    return this.#staticPropertyWithReplacementFallback({
      property: "hidden",
      args,
      defaultValue: null,
    });
  }

  @bind
  delegateShouldRenderToTemplate(args) {
    return this.#staticPropertyWithReplacementFallback({
      property: "delegateShouldRenderToTemplate",
      args,
      defaultValue: false,
    });
  }

  @bind
  extraControls(args) {
    return this.#staticPropertyWithReplacementFallback({
      property: "extraControls",
      args,
      defaultValue: false,
    });
  }

  get key() {
    return this.#key;
  }

  get position() {
    return this.#position;
  }

  @bind
  setShowLabel(value) {
    this.#showLabel = value;
  }

  @bind
  shouldRender(args) {
    return this.#staticPropertyWithReplacementFallback({
      property: "shouldRender",
      args,
      defaultValue: true,
    });
  }

  @bind
  showLabel(args) {
    return (
      this.#showLabel ??
      this.#staticPropertyWithReplacementFallback({
        property: "showLabel",
        args,
        defaultValue: null,
      })
    );
  }

  #staticPropertyWithReplacementFallback(
    { klass = this.#Component, property, args, defaultValue },
    _usedKlasses = new WeakSet()
  ) {
    // fallback to the default value if the klass is not defined, i.e., the button was not replaced
    // or if the klass was already used to avoid an infinite recursion in case of a circular reference
    if (!klass || _usedKlasses.has(klass)) {
      return defaultValue;
    }

    let value;
    if (typeof klass[property] === "function") {
      value = klass[property](args, helperContext(), this.#owner);
    } else {
      value = klass[property];
    }

    return (
      value ??
      this.#staticPropertyWithReplacementFallback(
        {
          klass: this.#replacementMap.get(klass) || null, // passing null explicitly to avoid using the default value
          property,
          args,
          defaultValue,
        },
        _usedKlasses.add(klass)
      )
    );
  }
}
