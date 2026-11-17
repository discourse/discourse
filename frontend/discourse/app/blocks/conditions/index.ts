// BlockCondition class and decorator
export { BlockCondition } from "./condition.ts";
export type {
  ConditionContext,
  ConditionResolvedValue,
  ConditionSourceType,
  ConditionValidateFn,
} from "./condition.ts";
export { blockCondition } from "./decorator.ts";
export type { BlockConditionConfig } from "./decorator.ts";

// Built-in condition classes
// Registered by the freeze-block-registry initializer
export { default as BlockOutletArgCondition } from "./outlet-arg.ts";
export { default as BlockRouteCondition } from "./route.ts";
export { default as BlockUserCondition } from "./user.ts";
export { default as BlockSettingCondition } from "./setting.ts";
export { default as BlockViewportCondition } from "./viewport.ts";
