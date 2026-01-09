// BlockCondition class and decorator
export { BlockCondition } from "./condition";
export { blockCondition } from "./decorator";

// Built-in condition classes
// The BlockConditionEvaluator service discovers these via `import *` and inheritance check
export { default as BlockOutletArgCondition } from "./outlet-arg";
export { default as BlockRouteCondition } from "./route";
export { default as BlockUserCondition } from "./user";
export { default as BlockSettingCondition } from "./setting";
export { default as BlockViewportCondition } from "./viewport";
