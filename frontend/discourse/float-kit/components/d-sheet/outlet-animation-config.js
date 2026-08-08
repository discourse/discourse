import { createTweenFunction } from "./animation";
import { toKebabCase, TRANSFORM_PROPS } from "./css-utils";

function addTransformTemplate(templates, property, animationFunction) {
  const wrappedFunction =
    property === "transform"
      ? animationFunction
      : (params) => `${property}(${animationFunction(params)})`;
  const transformIndex = templates.findIndex(([name]) => name === "transform");

  if (transformIndex === -1) {
    templates.push(["transform", wrappedFunction]);
    return;
  }

  const previousFunction = templates[transformIndex][1];
  templates[transformIndex][1] = (params) =>
    `${previousFunction(params)} ${wrappedFunction(params)}`;
}

export function normalizeOutletAnimationConfig(config) {
  const templates = [];
  const staticStyles = new Map();
  const animatedProperties = new Set();

  if (!config) {
    return { animatedProperties, staticStyles, templates };
  }

  const properties = Object.hasOwn(config, "properties")
    ? config.properties
    : config;

  for (const [property, value] of Object.entries(properties)) {
    if (!value || value === "ignore") {
      continue;
    }

    if (typeof value === "string") {
      const cssProperty = toKebabCase(property);
      staticStyles.set(cssProperty, value);
      continue;
    }

    if (typeof value === "function") {
      if (TRANSFORM_PROPS.has(property) || property === "transform") {
        addTransformTemplate(templates, property, value);
        animatedProperties.add("transform");
      } else {
        templates.push([property, value]);
        animatedProperties.add(toKebabCase(property));
      }
      continue;
    }

    if (!Array.isArray(value)) {
      continue;
    }

    const animationFunction = ({ tween }) => tween(value[0], value[1]);

    if (property === "opacity") {
      templates.push([property, animationFunction]);
      animatedProperties.add(property);
      continue;
    }

    if (
      !property.startsWith("scale") &&
      (!isNaN(value[0]) || !isNaN(value[1]))
    ) {
      throw new Error(
        "Keyframe values used with a 'transform' property require a unit (e.g. 'px', 'em' or '%')."
      );
    }

    addTransformTemplate(templates, property, animationFunction);
    animatedProperties.add("transform");
  }

  return { animatedProperties, staticStyles, templates };
}

export function createOutletAnimationKeyframe(templates, progress) {
  const keyframe = {};
  const tween = createTweenFunction(progress);

  for (const [property, animationFunction] of templates) {
    keyframe[property] = animationFunction({ progress, tween });
  }

  return keyframe;
}
