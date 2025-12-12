import { isWebKit } from "./browser-detection";

/**
 * Calculate bezier curve value at parameter t.
 *
 * @param {number} t - Parameter value (0-1)
 * @param {number} p1 - First control point
 * @param {number} p2 - Second control point
 * @returns {number} Bezier value at t
 */
function bezierValue(t, p1, p2) {
  return ((1 - 3 * p2 + 3 * p1) * t + (3 * p2 - 6 * p1)) * t * t + 3 * p1 * t;
}

/**
 * Calculate bezier curve derivative at parameter t.
 *
 * @param {number} t - Parameter value (0-1)
 * @param {number} p1 - First control point
 * @param {number} p2 - Second control point
 * @returns {number} Derivative value at t
 */
function bezierDerivative(t, p1, p2) {
  return 3 * (1 - 3 * p2 + 3 * p1) * t * t + 2 * (3 * p2 - 6 * p1) * t + 3 * p1;
}

/**
 * Refine t estimate using Newton-Raphson iteration.
 *
 * @param {number} x - Target x value
 * @param {number} guessT - Initial t estimate
 * @param {number} x1 - First control point x
 * @param {number} x2 - Second control point x
 * @returns {number} Refined t value
 */
function newtonRaphsonIterate(x, guessT, x1, x2) {
  for (let i = 0; i < 4; i++) {
    const derivative = bezierDerivative(guessT, x1, x2);
    if (derivative === 0) {
      break;
    }
    const currentX = bezierValue(guessT, x1, x2) - x;
    guessT -= currentX / derivative;
  }
  return guessT;
}

/**
 * Find t using binary subdivision when derivative is too small.
 *
 * @param {number} x - Target x value
 * @param {number} start - Start of interval
 * @param {number} end - End of interval
 * @param {number} x1 - First control point x
 * @param {number} x2 - Second control point x
 * @returns {number} Refined t value
 */
function binarySubdivide(x, start, end, x1, x2) {
  let mid;
  let currentX;
  let iterations = 0;

  do {
    mid = start + (end - start) / 2;
    currentX = bezierValue(mid, x1, x2) - x;
    if (currentX > 0) {
      end = mid;
    } else {
      start = mid;
    }
  } while (Math.abs(currentX) > 1e-7 && ++iterations < 10);

  return mid;
}

/**
 * Create a cubic bezier easing function.
 *
 * @param {number} x1 - First control point x
 * @param {number} y1 - First control point y
 * @param {number} x2 - Second control point x
 * @param {number} y2 - Second control point y
 * @returns {Function} Easing function that takes time (0-1) and returns progress (0-1)
 */
function createCubicBezierEasing(x1, y1, x2, y2) {
  if (!(0 <= x1 && x1 <= 1 && 0 <= x2 && x2 <= 1)) {
    throw new Error("bezier x values must be in [0, 1] range");
  }

  if (x1 === y1 && x2 === y2) {
    return (t) => t;
  }

  const sampleValues = new Float32Array(11);
  for (let i = 0; i < 11; i++) {
    sampleValues[i] = bezierValue(i * 0.1, x1, x2);
  }

  return (time) => {
    if (time === 0 || time === 1) {
      return time;
    }

    let intervalStart = 0;
    for (let i = 1; i < 11 && sampleValues[i] <= time; i++) {
      intervalStart += 0.1;
    }

    const intervalIndex = Math.floor(intervalStart * 10);
    const dist =
      (time - sampleValues[intervalIndex]) /
      (sampleValues[intervalIndex + 1] - sampleValues[intervalIndex]);
    const guessT = intervalStart + dist * 0.1;

    const derivative = bezierDerivative(guessT, x1, x2);

    if (derivative >= 0.001) {
      return bezierValue(newtonRaphsonIterate(time, guessT, x1, x2), y1, y2);
    } else if (derivative === 0) {
      return bezierValue(guessT, y1, y2);
    } else {
      return bezierValue(
        binarySubdivide(time, intervalStart, intervalStart + 0.1, x1, x2),
        y1,
        y2
      );
    }
  };
}

/**
 * Calculate spring animation values.
 *
 * @param {Object} config - Spring configuration
 * @param {number} [config.mass=1] - Mass
 * @param {number} [config.stiffness=300] - Stiffness
 * @param {number} [config.damping=34] - Damping
 * @param {number} [config.initialVelocity=0] - Initial velocity
 * @param {number} [config.fromPosition=0] - Starting position
 * @param {number} [config.toPosition=1] - Target position
 * @param {number} [config.precision=0.1] - Precision threshold
 * @returns {{ progressValuesArray: number[], duration: number }}
 */
function calculateSpringAnimation(config) {
  const {
    mass = 1,
    stiffness = 300,
    damping = 34,
    initialVelocity = 0,
    fromPosition = 0,
    toPosition = 1,
    precision = 0.1,
  } = config;

  const progressValues = [];
  let frameCount = 0;
  const distance = Math.abs(toPosition - fromPosition);

  if (distance === 0) {
    return {
      progressValuesArray: [1],
      duration: 1,
    };
  }

  let position = 0;
  let velocity = initialVelocity || 0;

  let isPositionStable = false;
  let isVelocityStable = false;

  const springConstant = -stiffness * 0.000001;
  const dampingConstant = -damping * 0.001;
  const velocityThreshold = precision / 22;
  const positionThreshold = precision * 10;

  while (!(isPositionStable && isVelocityStable)) {
    const springForce = springConstant * (position - distance);
    const dampingForce = dampingConstant * velocity;
    const acceleration = (springForce + dampingForce) / mass;

    velocity += acceleration;
    position += velocity;

    isVelocityStable = Math.abs(velocity) <= velocityThreshold;
    isPositionStable = Math.abs(distance - position) <= positionThreshold;

    const progress = position / distance;
    progressValues.push(progress);
    frameCount++;
  }

  return {
    progressValuesArray: progressValues,
    duration: frameCount,
  };
}

/**
 * Spring animation presets.
 *
 * @type {Object.<string, {stiffness: number, damping: number, mass: number}>}
 */
export const SPRING_PRESETS = {
  gentle: { stiffness: 560, damping: 68, mass: 1.85 },
  smooth: { stiffness: 580, damping: 60, mass: 1.35 },
  snappy: { stiffness: 350, damping: 34, mass: 0.9 },
  brisk: { stiffness: 350, damping: 28, mass: 0.65 },
  bouncy: { stiffness: 240, damping: 19, mass: 0.7 },
  elastic: { stiffness: 260, damping: 20, mass: 1 },
};

/**
 * Generate animation configuration from origin/destination and settings.
 *
 * @param {Object} config
 * @param {number} [config.origin=0] - Starting position
 * @param {number} [config.destination=1] - Target position
 * @param {Object} [config.animationConfig={}] - Animation settings
 * @returns {{ progressValuesArray: number[], easing: string, duration: number, delay: number }}
 */
export function generateAnimationConfig(config) {
  const { origin = 0, destination = 1, animationConfig = {} } = config;

  let progressValues = [];
  let duration;

  if (animationConfig.easing && animationConfig.easing !== "spring") {
    if (animationConfig.easing === "linear") {
      duration = animationConfig.duration || 250;
      const step = 1 / (duration - 1);
      for (let i = 0; i < duration; i++) {
        const progress = i * step;
        progressValues.push(isNaN(progress) ? 0 : progress);
      }
    } else {
      duration = animationConfig.duration || 250;
      let bezierPoints;

      switch (animationConfig.easing) {
        case "ease":
          bezierPoints = [0.25, 0.1, 0.25, 1];
          break;
        case "ease-in":
          bezierPoints = [0.42, 0, 1, 1];
          break;
        case "ease-out":
          bezierPoints = [0, 0, 0.58, 1];
          break;
        case "ease-in-out":
          bezierPoints = [0.42, 0, 0.58, 1];
          break;
        default:
          bezierPoints = [0.25, 0.1, 0.25, 1];
      }

      const easing = createCubicBezierEasing(...bezierPoints);
      for (let i = 0; i <= duration; i++) {
        progressValues.push(easing(i / duration));
      }
    }
  } else {
    const springResult = calculateSpringAnimation({
      stiffness: animationConfig.stiffness || 300,
      damping: animationConfig.damping || 34,
      mass: animationConfig.mass || 1,
      initialVelocity: animationConfig.initialVelocity || 0,
      precision: animationConfig.precision || 0.1,
      fromPosition: origin,
      toPosition: destination,
    });

    progressValues = springResult.progressValuesArray;
    duration = springResult.duration;
  }

  return {
    progressValuesArray: progressValues,
    easing: "linear",
    duration,
    delay: animationConfig.delay || 0,
  };
}

/**
 * Create a tween function for interpolating values based on progress.
 * Returns numeric values when both inputs are numbers, otherwise CSS calc expressions.
 *
 * @param {number} progress - Progress value (0-1)
 * @returns {Function} Tween function that interpolates between start and end values
 */
export function createTweenFunction(progress) {
  return (start, end) => {
    if (typeof start === "number" && typeof end === "number") {
      return start + (end - start) * progress;
    }
    return `calc(${start} + (${end} - ${start}) * ${progress})`;
  };
}

/**
 * Check if browser supports linear() easing function.
 *
 * @returns {boolean}
 */
export function supportsLinearEasing() {
  return (
    CSS.supports("transition-timing-function", "linear(0, 1)") && !isWebKit()
  );
}
