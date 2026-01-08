import { capabilities } from "discourse/services/capabilities";

/**
 * Constants for Bezier curve calculations.
 */
const NEWTON_RAPHSON_ITERATIONS = 4;
const BINARY_SUBDIVISION_THRESHOLD = 1e-7;
const BINARY_SUBDIVISION_ITERATIONS = 10;
const BEZIER_SAMPLE_SIZE = 11;
const BEZIER_SAMPLE_INTERVAL = 0.1;
const DERIVATIVE_THRESHOLD = 0.001;

/**
 * Default animation values.
 */
const DEFAULT_ANIMATION_DURATION = 250;
const SPRING_STIFFNESS_DEFAULT = 300;
const SPRING_DAMPING_DEFAULT = 34;
const SPRING_MASS_DEFAULT = 1;
const SPRING_PRECISION_DEFAULT = 0.1;

/**
 * Spring physics constants.
 */
const SPRING_CONSTANT_SCALE = 0.000001;
const DAMPING_CONSTANT_SCALE = 0.001;
const VELOCITY_THRESHOLD_SCALE = 22;
const POSITION_THRESHOLD_SCALE = 10;

/**
 * Standard CSS easing cubic-bezier points.
 */
const STANDARD_EASINGS = {
  ease: [0.25, 0.1, 0.25, 1],
  "ease-in": [0.42, 0, 1, 1],
  "ease-out": [0, 0, 0.58, 1],
  "ease-in-out": [0.42, 0, 0.58, 1],
};

/**
 * Parse a cubic-bezier string into an array of points.
 *
 * @param {string} easing - Easing string (e.g., "cubic-bezier(0.1, 0.7, 1.0, 0.1)")
 * @returns {number[]|null} Array of 4 points or null if invalid
 */
function parseCubicBezier(easing) {
  const prefix = "cubic-bezier(";
  if (!easing.startsWith(prefix)) {
    return null;
  }

  const points = easing
    .slice(prefix.length, -1)
    .split(",")
    .map((p) => parseFloat(p.trim()));

  return points.length === 4 && !points.some(isNaN) ? points : null;
}

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
  for (let i = 0; i < NEWTON_RAPHSON_ITERATIONS; i++) {
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
  } while (
    Math.abs(currentX) > BINARY_SUBDIVISION_THRESHOLD &&
    ++iterations < BINARY_SUBDIVISION_ITERATIONS
  );

  return mid;
}

/**
 * Find the parameter t for a given x value on the bezier curve.
 *
 * @param {number} x - Target x value
 * @param {number} x1 - First control point x
 * @param {number} x2 - Second control point x
 * @param {Float32Array|number[]} sampleValues - Sampled x values
 * @returns {number} Parameter t
 */
function getTForX(x, x1, x2, sampleValues) {
  let i = 1;
  for (; i < BEZIER_SAMPLE_SIZE - 1 && sampleValues[i] <= x; i++) {}
  i--;

  const intervalStart = i * BEZIER_SAMPLE_INTERVAL;
  const dist = (x - sampleValues[i]) / (sampleValues[i + 1] - sampleValues[i]);
  const guessT = intervalStart + dist * BEZIER_SAMPLE_INTERVAL;
  const derivative = bezierDerivative(guessT, x1, x2);

  if (derivative >= DERIVATIVE_THRESHOLD) {
    return newtonRaphsonIterate(x, guessT, x1, x2);
  } else if (derivative === 0) {
    return guessT;
  } else {
    return binarySubdivide(
      x,
      intervalStart,
      intervalStart + BEZIER_SAMPLE_INTERVAL,
      x1,
      x2
    );
  }
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

  const sampleValues =
    typeof Float32Array === "function"
      ? new Float32Array(BEZIER_SAMPLE_SIZE)
      : new Array(BEZIER_SAMPLE_SIZE);

  for (let i = 0; i < BEZIER_SAMPLE_SIZE; i++) {
    sampleValues[i] = bezierValue(i * BEZIER_SAMPLE_INTERVAL, x1, x2);
  }

  return (time) => {
    if (time === 0 || time === 1) {
      return time;
    }

    return bezierValue(getTForX(time, x1, x2, sampleValues), y1, y2);
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
  const mass = config.mass ?? SPRING_MASS_DEFAULT;
  const stiffness = config.stiffness ?? SPRING_STIFFNESS_DEFAULT;
  const damping = config.damping ?? SPRING_DAMPING_DEFAULT;
  const initialVelocity = config.initialVelocity ?? 0;
  const fromPosition = config.fromPosition ?? 0;
  const toPosition = config.toPosition ?? 1;
  const precision = config.precision ?? SPRING_PRECISION_DEFAULT;

  const progressValues = [];
  let frameCount = 0;
  const distance = Math.abs(toPosition - fromPosition);

  if (distance === 0) {
    return {
      progressValuesArray: [],
      duration: 0,
    };
  }

  let position = 0;
  let velocity = initialVelocity;

  let isPositionStable = false;
  let isVelocityStable = false;

  const springConstant = -stiffness * SPRING_CONSTANT_SCALE;
  const dampingConstant = -damping * DAMPING_CONSTANT_SCALE;
  const velocityThreshold = precision / VELOCITY_THRESHOLD_SCALE;
  const positionThreshold = precision * POSITION_THRESHOLD_SCALE;

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
  const origin = config.origin ?? 0;
  const destination = config.destination ?? 1;
  const animationConfig = config.animationConfig ?? {};

  let progressValues = [];
  let duration;

  if (animationConfig.easing && animationConfig.easing !== "spring") {
    duration = animationConfig.duration ?? DEFAULT_ANIMATION_DURATION;

    if (animationConfig.easing === "linear") {
      const step = 1 / (duration - 1);
      for (let i = 0; i < duration; i++) {
        const progress = i * step;
        progressValues.push(isNaN(progress) ? 0 : progress);
      }
    } else {
      let bezierPoints;
      if (STANDARD_EASINGS[animationConfig.easing]) {
        bezierPoints = STANDARD_EASINGS[animationConfig.easing];
      } else if (
        animationConfig.easing.startsWith("cubic-bezier") &&
        parseCubicBezier(animationConfig.easing)
      ) {
        bezierPoints = parseCubicBezier(animationConfig.easing);
      } else {
        bezierPoints = STANDARD_EASINGS.ease;
      }

      const easing = createCubicBezierEasing(...bezierPoints);
      for (let i = 0; i <= duration; i++) {
        progressValues.push(easing(i / duration));
      }
    }
  } else {
    const springResult = calculateSpringAnimation({
      stiffness: animationConfig.stiffness,
      damping: animationConfig.damping,
      mass: animationConfig.mass,
      initialVelocity: animationConfig.initialVelocity,
      precision: animationConfig.precision,
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
    delay: animationConfig.delay ?? 0,
  };
}

/**
 * Create a tween function for interpolating values based on progress.
 * Always returns CSS calc() expressions to let the browser handle interpolation.
 *
 * @param {number} progress - Progress value (0-1)
 * @returns {Function} Tween function (start, end) => CSS calc expression
 */
export function createTweenFunction(progress) {
  return (start, end) => {
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
    CSS.supports("transition-timing-function", "linear(0, 1)") &&
    !capabilities.isWebKit
  );
}
