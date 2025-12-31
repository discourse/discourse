// Base class, error, and validation helper
export {
  BlockCondition,
  BlockConditionValidationError,
  raiseBlockValidationError,
} from "./base";

// Built-in condition classes
// The BlockConditionEvaluator service discovers these via `import *` and inheritance check
export {
  default as BlockRouteCondition,
  BlockRouteConditionShortcuts,
} from "./route";
export { default as BlockUserCondition } from "./user";
export { default as BlockSettingCondition } from "./setting";
export { default as BlockViewportCondition } from "./viewport";
