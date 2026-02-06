import Modifier from "ember-modifier";
import { createTweenFunction } from "./animation";
import { toKebabCase, TRANSFORM_PROPS } from "./css-utils";

/**
 * Ember modifier that applies travel and stacking animations to a sheet outlet element.
 *
 * @extends Modifier
 */
export default class OutletAnimationModifier extends Modifier {
  /** @type {Function[]} */
  #cleanupFns = [];

  /** @type {Set<string>} */
  #propertiesToClean = new Set();

  /** Cleans up all registered animations on element destruction. */
  willDestroy() {
    this.#cleanup();
  }

  /**
   * Applies travel and stacking animations to the element when arguments change.
   *
   * @param {HTMLElement} element
   * @param {[Object|null, Object|undefined, Object|undefined]} positional - [sheet, travelAnimation, stackingAnimation]
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
   * Registers a single animation (travel or stacking) on the element via the sheet.
   *
   * @param {HTMLElement} element
   * @param {Object} sheet
   * @param {Object|undefined} animationConfig
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
      type === "travel"
        ? "registerTravelAnimation"
        : "registerStackingAnimation";

    const unregister = sheet[registerMethod]({
      target: element,
      config: animationConfig,
      callback: this.#createAnimationCallback(element, animatedProperties),
    });

    this.#cleanupFns.push(unregister);
  }

  /**
   * Parses an animation config into animated properties, static styles, and properties to clean.
   *
   * @param {Object|undefined} config
   * @returns {{ animatedProperties: Array<[string, Function]>, staticStyles: Map<string, string>, propertiesToClean: Set<string> }}
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
   * Determines whether a property should be skipped during animation preparation.
   *
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
   * Creates an animation function for a single property from a keyframe array or callback.
   *
   * @param {string} property
   * @param {[string, string]|Function} value
   * @returns {Function|null}
   */
  #createPropertyAnimationFn(property, value) {
    if (Array.isArray(value)) {
      if (
        !property.startsWith("scale") &&
        (!isNaN(value[0]) || !isNaN(value[1]))
      ) {
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
   * Adds a transform property, merging with any existing transform animation function.
   *
   * @param {Array<[string, Function]>} animatedProperties
   * @param {Set<string>} propertiesToClean
   * @param {string} property
   * @param {Function} animationFn
   */
  #addTransformProperty(
    animatedProperties,
    propertiesToClean,
    property,
    animationFn
  ) {
    const transformName = property === "transform" ? "" : property;

    const wrappedFn = (params) => {
      const val = animationFn(params);
      return transformName ? `${transformName}(${val})` : val;
    };

    const existingIndex = animatedProperties.findIndex(
      ([p]) => p === "transform"
    );

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
   * Applies non-animated CSS styles directly to the element.
   *
   * @param {HTMLElement} element
   * @param {Map<string, string>} staticStyles
   */
  #applyStaticStyles(element, staticStyles) {
    for (const [prop, value] of staticStyles) {
      element.style.setProperty(prop, value);
    }
  }

  /**
   * Creates a callback that applies animated CSS property values on each animation frame.
   *
   * @param {HTMLElement} element
   * @param {Array<[string, Function]>} animatedProperties
   * @returns {(progress: number, tween?: Function) => void}
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

  /**
   * Unregisters all animations and removes applied CSS properties from the element.
   *
   * @param {HTMLElement} [element]
   */
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
}
