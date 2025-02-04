import deprecated from "discourse/lib/deprecated";
export { default, flushMap } from "discourse/services/store";

deprecated(
  `"discourse/models/store" import is deprecated, use "discourse/services/store" instead`,
  {
    since: "2.8.0.beta8",
    dropFrom: "2.9.0.beta1",
    id: "discourse.models-store",
  }
);
