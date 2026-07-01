import { capabilities } from "discourse/services/capabilities";

const NEWTON_RAPHSON_ITERATIONS = 4;
const BINARY_SUBDIVISION_THRESHOLD = 1e-7;
const BINARY_SUBDIVISION_ITERATIONS = 10;
const BEZIER_SAMPLE_SIZE = 11;
const BEZIER_SAMPLE_INTERVAL = 0.1;
const DERIVATIVE_THRESHOLD = 0.001;

const DEFAULT_ANIMATION_DURATION = 250;
const SPRING_STIFFNESS_DEFAULT = 300;
const SPRING_DAMPING_DEFAULT = 34;
const SPRING_MASS_DEFAULT = 1;
const SPRING_PRECISION_DEFAULT = 0.1;

const SPRING_CONSTANT_SCALE = 0.000001;
const DAMPING_CONSTANT_SCALE = 0.001;
const VELOCITY_THRESHOLD_SCALE = 22;
const POSITION_THRESHOLD_SCALE = 10;
const STANDARD_EASINGS = {
  ease: [0.25, 0.1, 0.25, 1],
  "ease-in": [0.42, 0, 1, 1],
  "ease-out": [0, 0, 0.58, 1],
  "ease-in-out": [0.42, 0, 0.58, 1],
};
export function parseCubicBezier(easing) {
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
function bezierValue(t, p1, p2) {
  return (((1 - 3 * p2 + 3 * p1) * t + (3 * p2 - 6 * p1)) * t + 3 * p1) * t;
}
function bezierDerivative(t, p1, p2) {
  return 3 * (1 - 3 * p2 + 3 * p1) * t * t + 2 * (3 * p2 - 6 * p1) * t + 3 * p1;
}
function newtonRaphsonIterate(x, guessT, x1, x2) {
  for (let i = 0; i < NEWTON_RAPHSON_ITERATIONS; ++i) {
    const derivative = bezierDerivative(guessT, x1, x2);
    if (derivative === 0) {
      break;
    }
    const currentX = bezierValue(guessT, x1, x2) - x;
    guessT -= currentX / derivative;
  }
  return guessT;
}
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
function getTForX(x, x1, x2, sampleValues) {
  let intervalStart = 0;
  let i = 1;
  for (; i !== BEZIER_SAMPLE_SIZE - 1 && sampleValues[i] <= x; ++i) {
    intervalStart += BEZIER_SAMPLE_INTERVAL;
  }
  const guessT =
    intervalStart +
    ((x - sampleValues[--i]) / (sampleValues[i + 1] - sampleValues[i])) *
      BEZIER_SAMPLE_INTERVAL;
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
export function createCubicBezierEasing(x1, y1, x2, y2) {
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

  for (let i = 0; i < BEZIER_SAMPLE_SIZE; ++i) {
    sampleValues[i] = bezierValue(i * BEZIER_SAMPLE_INTERVAL, x1, x2);
  }

  return (time) => {
    if (time === 0 || time === 1) {
      return time;
    }

    return bezierValue(getTForX(time, x1, x2, sampleValues), y1, y2);
  };
}
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
export const SPRING_PRESETS = {
  gentle: { stiffness: 560, damping: 68, mass: 1.85 },
  smooth: { stiffness: 580, damping: 60, mass: 1.35 },
  snappy: { stiffness: 350, damping: 34, mass: 0.9 },
  brisk: { stiffness: 350, damping: 28, mass: 0.65 },
  bouncy: { stiffness: 240, damping: 19, mass: 0.7 },
  elastic: { stiffness: 260, damping: 20, mass: 1 },
};
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
export function createTweenFunction(progress) {
  return (start, end) => {
    return `calc(${start} + (${end} - ${start}) * ${progress})`;
  };
}
export function supportsLinearEasing() {
  return (
    CSS.supports("transition-timing-function", "linear(0, 1)") &&
    !capabilities.isWebKit
  );
}
