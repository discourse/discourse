import { modifier } from "ember-modifier";

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
 * Applies stacking animation transforms to an element.
 *
 * @param {HTMLElement} element - Target element
 * @param {Object} stackingAnimation - Animation config with transform properties
 * @param {number} progress - Stacking progress (0 = no sheets above, 1+ = sheets stacked)
 */
function applyStackingAnimation(element, stackingAnimation, progress) {
  if (!stackingAnimation || !element) {
    return;
  }

  const transforms = [];
  let transformOrigin = null;

  for (const [property, value] of Object.entries(stackingAnimation)) {
    if (value === null || value === undefined) {
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

    const transformProps = [
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

    if (transformProps.includes(property)) {
      transforms.push(`${property}(${computedValue})`);
    } else if (property === "opacity") {
      element.style.opacity = computedValue;
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

const DEFAULT_STACKING_ANIMATION = {
  translateY: ({ progress }) => {
    return progress <= 1
      ? `${-1.3 * progress}vh`
      : `calc(-1.3vh + 0.65vh * ${progress - 1})`;
  },
  scale: [1, 0.91],
  transformOrigin: "50% 0",
};

/**
 * Modifier that applies stacking animations to sheet content.
 *
 * @param {HTMLElement} element - Target element
 * @param {Object} sheet - The sheet controller instance
 * @param {Object} [stackingAnimation] - Custom stacking animation config (optional)
 */
export default modifier((element, [sheet, stackingAnimation]) => {
  if (!sheet) {
    return;
  }

  const animation =
    stackingAnimation || (sheet.stackId ? DEFAULT_STACKING_ANIMATION : null);

  if (!animation) {
    return;
  }

  const unregister = sheet.registerStackingAnimation({
    target: element,
    config: animation,
    callback: (progress) => {
      applyStackingAnimation(element, animation, progress);
    },
  });

  return () => {
    unregister?.();
    element.style.transform = "";
    element.style.transformOrigin = "";
  };
});

