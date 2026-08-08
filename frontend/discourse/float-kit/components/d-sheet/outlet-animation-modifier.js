import { registerDestructor } from "@ember/destroyable";
import Modifier from "ember-modifier";
import { createTweenFunction } from "./animation";
import { toKebabCase } from "./css-utils";
import { normalizeOutletAnimationConfig } from "./outlet-animation-config";

export default class OutletAnimationModifier extends Modifier {
  #cleanupFns = [];
  #staticProperties = new Set();
  #element = null;
  #sheet = null;
  #travelAnimation = null;
  #stackingAnimation = null;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.#cleanup());
  }

  modify(element, [sheet, travelAnimation, stackingAnimation]) {
    if (
      element === this.#element &&
      sheet === this.#sheet &&
      travelAnimation === this.#travelAnimation &&
      stackingAnimation === this.#stackingAnimation
    ) {
      return;
    }

    if (element !== this.#element || sheet !== this.#sheet) {
      this.#cleanup(this.#element);
    } else {
      this.#unregisterAnimations();
      this.#removeStaticStyles(element);
    }

    this.#element = element;
    this.#sheet = sheet;
    this.#travelAnimation = travelAnimation;
    this.#stackingAnimation = stackingAnimation;

    if (!sheet) {
      return;
    }

    this.#registerAnimation(element, sheet, travelAnimation, "travel");
    this.#registerAnimation(element, sheet, stackingAnimation, "stacking");
  }

  #registerAnimation(element, sheet, animationConfig, type) {
    if (!animationConfig) {
      return;
    }

    const { animatedProperties, staticStyles, templates } =
      normalizeOutletAnimationConfig(animationConfig);

    this.#applyStaticStyles(element, staticStyles);

    const registerMethod =
      type === "travel"
        ? "registerTravelAnimation"
        : "registerStackingAnimation";

    const unregister = sheet[registerMethod]({
      target: element,
      config: animationConfig,
      animatedProperties,
      templates,
      callback: this.#createAnimationCallback(element, templates),
    });

    this.#cleanupFns.push(unregister);
  }

  #applyStaticStyles(element, staticStyles) {
    for (const [prop, value] of staticStyles) {
      element.style.setProperty(prop, value);
      this.#staticProperties.add(prop);
    }
  }

  #createAnimationCallback(element, templates) {
    const len = templates.length;

    return (progress, tween) => {
      const tweenFn = tween || createTweenFunction(progress);
      const params = { progress, tween: tweenFn };

      for (let i = 0; i < len; i++) {
        const [property, animationFunction] = templates[i];
        element.style.setProperty(
          toKebabCase(property),
          animationFunction(params)
        );
      }
    };
  }

  #unregisterAnimations() {
    for (const fn of this.#cleanupFns) {
      fn?.();
    }
    this.#cleanupFns = [];
  }

  #removeStaticStyles(element) {
    for (const prop of this.#staticProperties) {
      element?.style.removeProperty(prop);
    }
    this.#staticProperties.clear();
  }

  #cleanup(element = this.#element) {
    this.#unregisterAnimations();
    this.#removeStaticStyles(element);
    this.#element = null;
    this.#sheet = null;
    this.#travelAnimation = null;
    this.#stackingAnimation = null;
  }
}
