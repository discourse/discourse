import Modifier from "ember-modifier";
import { createTweenFunction } from "./animation";
import { toKebabCase, TRANSFORM_PROPS } from "./css-utils";

/**
 * Modifier that applies both travel and stacking animations to an element.
 * Optimized to pre-calculate animation callbacks and static styles.
 */
export default class OutletAnimationModifier extends Modifier {
  /** @type {Function[]} */
  #cleanupFns = [];

  /** @type {Set<string>} */
  #propertiesToClean = new Set();

  /**
   * Main lifecycle hook for the modifier.
   *
   * @param {HTMLElement} element - Target element
   * @param {Array} args - Positional arguments [sheet, travelAnimation, stackingAnimation]
   */
  modify(element, [sheet, travelAnimation, stackingAnimation]) {
    this.#cleanup(element);

    if (!sheet) {
      return;
    }

    if (travelAnimation) {
      const { animatedProperties, staticStyles, propertiesToClean } =
        this.#prepareAnimation(travelAnimation);

      this.#applyStaticStyles(element, staticStyles);
      for (const prop of propertiesToClean) {
        this.#propertiesToClean.add(prop);
      }

      const unregister = sheet.registerTravelAnimation({
        target: element,
        config: travelAnimation,
        callback: this.#createAnimationCallback(element, animatedProperties),
      });

      this.#cleanupFns.push(unregister);
    }

    if (stackingAnimation) {
      const { animatedProperties, staticStyles, propertiesToClean } =
        this.#prepareAnimation(stackingAnimation);

      this.#applyStaticStyles(element, staticStyles);
      for (const prop of propertiesToClean) {
        this.#propertiesToClean.add(prop);
      }

      const unregister = sheet.registerStackingAnimation({
        target: element,
        config: stackingAnimation,
        callback: this.#createAnimationCallback(element, animatedProperties),
      });

      this.#cleanupFns.push(unregister);
    }
  }

  /**
   * Prepares animation configuration into executable callbacks and static styles.
   *
   * @param {Object} config - Animation configuration
   * @returns {Object} Prepared animation data
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
      if (
        value === null ||
        value === undefined ||
        value === "ignore" ||
        property === "properties"
      ) {
        continue;
      }

      if (property === "transformOrigin") {
        const kebabProp = "transform-origin";
        staticStyles.set(kebabProp, value);
        propertiesToClean.add(kebabProp);
        continue;
      }

      if (typeof value === "string") {
        const kebabProp = toKebabCase(property);
        staticStyles.set(kebabProp, value);
        propertiesToClean.add(kebabProp);
        continue;
      }

      let animationFn;
      if (Array.isArray(value)) {
        if (
          !property.startsWith("scale") &&
          (!isNaN(value[0]) || !isNaN(value[1]))
        ) {
          throw new Error(
            "Keyframe values used with a 'transform' property require a unit (e.g. 'px', 'em' or '%')."
          );
        }

        animationFn = ({ tween }) => tween(value[0], value[1]);
      } else if (typeof value === "function") {
        animationFn = value;
      } else {
        continue;
      }

      if (TRANSFORM_PROPS.has(property) || property === "transform") {
        const transformName = property === "transform" ? "" : property;

        const existingTransformIndex = animatedProperties.findIndex(
          ([p]) => p === "transform"
        );

        const wrappedFn = (params) => {
          const val = animationFn(params);
          return transformName ? `${transformName}(${val})` : val;
        };

        if (existingTransformIndex !== -1) {
          const prevFn = animatedProperties[existingTransformIndex][1];
          animatedProperties[existingTransformIndex][1] = (params) =>
            `${prevFn(params)} ${wrappedFn(params)}`;
        } else {
          animatedProperties.push(["transform", wrappedFn]);
          propertiesToClean.add("transform");
        }
      } else {
        const kebabProp = toKebabCase(property);
        animatedProperties.push([kebabProp, animationFn]);
        propertiesToClean.add(kebabProp);
      }
    }

    return { animatedProperties, staticStyles, propertiesToClean };
  }

  /**
   * Applies static styles to an element immediately.
   *
   * @param {HTMLElement} element - Target element
   * @param {Map<string, string>} staticStyles - Static styles to apply
   */
  #applyStaticStyles(element, staticStyles) {
    for (const [prop, value] of staticStyles) {
      element.style.setProperty(prop, value);
    }
  }

  /**
   * Creates an optimized animation callback for the element.
   *
   * @param {HTMLElement} element - Target element
   * @param {Array} animatedProperties - Array of [prop, fn] pairs
   * @returns {Function} Animation callback
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
   * Cleans up registered animations and resets styles.
   *
   * @param {HTMLElement} element - Target element
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

  /**
   * Final cleanup on destruction.
   */
  willDestroy() {
    this.#cleanup();
  }
}
