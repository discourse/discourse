import { modifier } from "ember-modifier";
import { createTweenFunction } from "./animation";
import { toKebabCase, TRANSFORM_PROPS } from "./css-utils";

/**
 * Applies animation config to an element at a given progress.
 * Handles CSS properties including transforms, opacity, visibility, etc.
 *
 * @param {HTMLElement} element - Target element
 * @param {Object} config - Animation config with CSS property values
 * @param {number} progress - Animation progress (0 to 1)
 * @param {Function} [tween] - Optional tween function for interpolation
 */
function applyAnimation(element, config, progress, tween) {
  if (!config || !element) {
    return;
  }

  const tweenFn = tween || createTweenFunction(progress);
  const transforms = [];

  for (const [property, value] of Object.entries(config)) {
    if (
      value === null ||
      value === undefined ||
      value === "ignore" ||
      property === "transformOrigin"
    ) {
      continue;
    }

    let computedValue;

    if (Array.isArray(value)) {
      computedValue = tweenFn(value[0], value[1]);
    } else if (typeof value === "function") {
      computedValue = value({ progress, tween: tweenFn });
    } else if (typeof value === "string") {
      computedValue = value;
    } else {
      continue;
    }

    if (TRANSFORM_PROPS.has(property)) {
      transforms.push(`${property}(${computedValue})`);
    } else {
      element.style.setProperty(toKebabCase(property), computedValue);
    }
  }

  if (transforms.length > 0) {
    element.style.setProperty("transform", transforms.join(" "));
  }

  if (config.transformOrigin) {
    element.style.setProperty("transform-origin", config.transformOrigin);
  }
}

/**
 * Collects CSS property names from config for cleanup.
 *
 * @param {Object} config - Animation config
 * @returns {string[]} Array of kebab-case CSS property names to clean up
 */
function getPropertiesToClean(config) {
  if (!config) {
    return [];
  }

  const properties = [];
  let hasTransform = false;

  for (const property of Object.keys(config)) {
    if (TRANSFORM_PROPS.has(property)) {
      hasTransform = true;
    } else if (property !== "transformOrigin") {
      properties.push(toKebabCase(property));
    }
  }

  if (hasTransform) {
    properties.push("transform");
  }

  if (config.transformOrigin) {
    properties.push("transform-origin");
  }

  return properties;
}

/**
 * Modifier that applies both travel and stacking animations to an element.
 *
 * @param {HTMLElement} element - Target element
 * @param {Object} sheet - The sheet controller instance
 * @param {Object} [travelAnimation] - Travel animation config (optional)
 * @param {Object} [stackingAnimation] - Stacking animation config (optional)
 */
export default modifier(
  (element, [sheet, travelAnimation, stackingAnimation]) => {
    if (!sheet) {
      return;
    }

    const cleanupFns = [];
    const propertiesToClean = new Set();

    if (travelAnimation) {
      for (const prop of getPropertiesToClean(travelAnimation)) {
        propertiesToClean.add(prop);
      }

      const unregister = sheet.registerTravelAnimation({
        target: element,
        config: travelAnimation,
        callback: (progress, tween) => {
          applyAnimation(element, travelAnimation, progress, tween);
        },
      });

      cleanupFns.push(unregister);
    }

    if (stackingAnimation) {
      for (const prop of getPropertiesToClean(stackingAnimation)) {
        propertiesToClean.add(prop);
      }

      const unregister = sheet.registerStackingAnimation({
        target: element,
        config: stackingAnimation,
        callback: (progress, tween) => {
          applyAnimation(element, stackingAnimation, progress, tween);
        },
      });

      cleanupFns.push(unregister);
    }

    return () => {
      for (const fn of cleanupFns) {
        fn?.();
      }

      for (const prop of propertiesToClean) {
        element.style.removeProperty(prop);
      }
    };
  }
);
