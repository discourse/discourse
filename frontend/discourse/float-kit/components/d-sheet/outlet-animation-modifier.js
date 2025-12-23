import Modifier from "ember-modifier";
import { createTweenFunction } from "./animation";
import { toKebabCase, TRANSFORM_PROPS } from "./css-utils";

export default class OutletAnimationModifier extends Modifier {
  /** @type {Function[]} */
  #cleanupFns = [];

  /** @type {Set<string>} */
  #propertiesToClean = new Set();

  /**
   * @param {HTMLElement} element
   * @param {Array} args - [sheet, travelAnimation, stackingAnimation]
   */
  modify(element, [sheet, travelAnimation, stackingAnimation]) {
    this.#cleanup(element);

    if (!sheet) {
      return;
    }

    this.#registerAnimation(element, sheet, travelAnimation, "travel");
    this.#registerAnimation(element, sheet, stackingAnimation, "stacking");
  }

  /**
   * @param {HTMLElement} element
   * @param {Object} sheet
   * @param {Object} animationConfig
   * @param {"travel"|"stacking"} type
   */
  #registerAnimation(element, sheet, animationConfig, type) {
    if (!animationConfig) {
      return;
    }

    const { animatedProperties, staticStyles, propertiesToClean } =
      this.#prepareAnimation(animationConfig);

    this.#applyStaticStyles(element, staticStyles);

    for (const prop of propertiesToClean) {
      this.#propertiesToClean.add(prop);
    }

    const registerMethod =
      type === "travel" ? "registerTravelAnimation" : "registerStackingAnimation";

    const unregister = sheet[registerMethod]({
      target: element,
      config: animationConfig,
      callback: this.#createAnimationCallback(element, animatedProperties),
    });

    this.#cleanupFns.push(unregister);
  }

  /**
   * @param {Object} config
   * @returns {{ animatedProperties: Array, staticStyles: Map, propertiesToClean: Set }}
   */
  #prepareAnimation(config) {
    const animatedProperties = [];
    const staticStyles = new Map();
    const propertiesToClean = new Set();

    if (!config) {
      return { animatedProperties, staticStyles, propertiesToClean };
    }

    const props = config.properties || config;

    for (const [property, value] of Object.entries(props)) {
      if (this.#shouldSkipProperty(property, value)) {
        continue;
      }

      if (property === "transformOrigin") {
        staticStyles.set("transform-origin", value);
        propertiesToClean.add("transform-origin");
        continue;
      }

      if (typeof value === "string") {
        const kebabProp = toKebabCase(property);
        staticStyles.set(kebabProp, value);
        propertiesToClean.add(kebabProp);
        continue;
      }

      const animationFn = this.#createPropertyAnimationFn(property, value);
      if (!animationFn) {
        continue;
      }

      if (TRANSFORM_PROPS.has(property) || property === "transform") {
        this.#addTransformProperty(
          animatedProperties,
          propertiesToClean,
          property,
          animationFn
        );
      } else {
        const kebabProp = toKebabCase(property);
        animatedProperties.push([kebabProp, animationFn]);
        propertiesToClean.add(kebabProp);
      }
    }

    return { animatedProperties, staticStyles, propertiesToClean };
  }

  /**
   * @param {string} property
   * @param {*} value
   * @returns {boolean}
   */
  #shouldSkipProperty(property, value) {
    return (
      value === null ||
      value === undefined ||
      value === "ignore" ||
      property === "properties"
    );
  }

  /**
   * @param {string} property
   * @param {Array|Function} value
   * @returns {Function|null}
   */
  #createPropertyAnimationFn(property, value) {
    if (Array.isArray(value)) {
      if (!property.startsWith("scale") && (!isNaN(value[0]) || !isNaN(value[1]))) {
        throw new Error(
          "Keyframe values used with a 'transform' property require a unit (e.g. 'px', 'em' or '%')."
        );
      }
      return ({ tween }) => tween(value[0], value[1]);
    }

    if (typeof value === "function") {
      return value;
    }

    return null;
  }

  /**
   * @param {Array} animatedProperties
   * @param {Set} propertiesToClean
   * @param {string} property
   * @param {Function} animationFn
   */
  #addTransformProperty(animatedProperties, propertiesToClean, property, animationFn) {
    const transformName = property === "transform" ? "" : property;

    const wrappedFn = (params) => {
      const val = animationFn(params);
      return transformName ? `${transformName}(${val})` : val;
    };

    const existingIndex = animatedProperties.findIndex(([p]) => p === "transform");

    if (existingIndex !== -1) {
      const prevFn = animatedProperties[existingIndex][1];
      animatedProperties[existingIndex][1] = (params) =>
        `${prevFn(params)} ${wrappedFn(params)}`;
    } else {
      animatedProperties.push(["transform", wrappedFn]);
      propertiesToClean.add("transform");
    }
  }

  /**
   * @param {HTMLElement} element
   * @param {Map<string, string>} staticStyles
   */
  #applyStaticStyles(element, staticStyles) {
    for (const [prop, value] of staticStyles) {
      element.style.setProperty(prop, value);
    }
  }

  /**
   * @param {HTMLElement} element
   * @param {Array<[string, Function]>} animatedProperties
   * @returns {Function}
   */
  #createAnimationCallback(element, animatedProperties) {
    const len = animatedProperties.length;

    return (progress, tween) => {
      const tweenFn = tween || createTweenFunction(progress);
      const params = { progress, tween: tweenFn };

      for (let i = 0; i < len; i++) {
        const [prop, fn] = animatedProperties[i];
        element.style.setProperty(prop, fn(params));
      }
    };
  }

  /** @param {HTMLElement} element */
  #cleanup(element) {
    for (const fn of this.#cleanupFns) {
      fn?.();
    }
    this.#cleanupFns = [];

    if (element) {
      for (const prop of this.#propertiesToClean) {
        element.style.removeProperty(prop);
      }
    }
    this.#propertiesToClean.clear();
  }

  willDestroy() {
    this.#cleanup();
  }
}
