import { modifier } from "ember-modifier";

/**
 * CSS transform properties that should be combined into a single transform string.
 * @type {string[]}
 */
const TRANSFORM_PROPS = [
  "translate",
  "translateX",
  "translateY",
  "translateZ",
  "scale",
  "scaleX",
  "scaleY",
  "scaleZ",
  "rotate",
  "rotateX",
  "rotateY",
  "rotateZ",
  "skew",
  "skewX",
  "skewY",
];

/**
 * Interpolates between two values based on progress.
 *
 * @param {number|string} start - Start value (can include unit like "10px")
 * @param {number|string} end - End value
 * @param {number} progress - Progress from 0 to 1
 * @returns {string} Interpolated value with unit
 */
function tween(start, end, progress) {
  const startNum = typeof start === "string" ? parseFloat(start) : start;
  const endNum = typeof end === "string" ? parseFloat(end) : end;
  const unit = typeof start === "string" ? start.replace(/[\d.-]/g, "") : "";
  return startNum + (endNum - startNum) * Math.min(progress, 1) + unit;
}

/**
 * Applies animation config to an element at a given progress.
 * Handles all CSS properties including transforms, opacity, visibility, etc.
 *
 * @param {HTMLElement} element - Target element
 * @param {Object} config - Animation config with CSS property values
 * @param {number} progress - Animation progress (0 to 1)
 */
function applyAnimation(element, config, progress) {
  if (!config || !element) {
    return;
  }

  const transforms = [];
  let transformOrigin = null;

  for (const [property, value] of Object.entries(config)) {
    if (value === null || value === undefined || value === "ignore") {
      continue;
    }

    if (property === "transformOrigin") {
      transformOrigin = value;
      continue;
    }

    let computedValue;

    if (Array.isArray(value)) {
      computedValue = tween(value[0], value[1], progress);
    } else if (typeof value === "function") {
      computedValue = value({
        progress,
        tween: (start, end) => tween(start, end, progress),
      });
    } else if (typeof value === "string") {
      computedValue = value;
    } else {
      continue;
    }

    if (TRANSFORM_PROPS.includes(property)) {
      transforms.push(`${property}(${computedValue})`);
    } else {
      element.style[property] = computedValue;
    }
  }

  if (transforms.length > 0) {
    element.style.transform = transforms.join(" ");
  }

  if (transformOrigin) {
    element.style.transformOrigin = transformOrigin;
  }
}

/**
 * Collects all CSS properties from a config for cleanup.
 *
 * @param {Object} config - Animation config
 * @returns {string[]} Array of CSS property names to clean up
 */
function getPropertiesToClean(config) {
  if (!config) {
    return [];
  }

  const properties = [];
  let hasTransform = false;

  for (const property of Object.keys(config)) {
    if (TRANSFORM_PROPS.includes(property)) {
      hasTransform = true;
    } else if (property !== "transformOrigin") {
      properties.push(property);
    }
  }

  if (hasTransform) {
    properties.push("transform");
  }

  if (config.transformOrigin) {
    properties.push("transformOrigin");
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
      const travelProps = getPropertiesToClean(travelAnimation);
      travelProps.forEach((p) => propertiesToClean.add(p));

      const unregister = sheet.registerTravelAnimation({
        target: element,
        config: travelAnimation,
        callback: (progress) => {
          applyAnimation(element, travelAnimation, progress);
        },
      });

      cleanupFns.push(unregister);
    }

    if (stackingAnimation) {
      const stackingProps = getPropertiesToClean(stackingAnimation);
      stackingProps.forEach((p) => propertiesToClean.add(p));

      const unregister = sheet.registerStackingAnimation({
        target: element,
        config: stackingAnimation,
        callback: (progress) => {
          applyAnimation(element, stackingAnimation, progress);
        },
      });

      cleanupFns.push(unregister);
    }

    return () => {
      cleanupFns.forEach((fn) => fn?.());

      for (const property of propertiesToClean) {
        element.style[property] = "";
      }
    };
  }
);
