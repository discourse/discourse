import deprecated from "discourse/lib/deprecated";

export function registerOption() {
  deprecated(
    "`registerOption() from `pretty-text` is deprecated. Use `helper.registerOptions()` instead.",
    {
      since: "2.8.0.beta9",
      dropFrom: "2.9.0.beta1",
      id: "discourse.pretty-text.registerOption",
    }
  );
}
