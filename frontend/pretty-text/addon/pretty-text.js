import deprecated from "discourse/lib/deprecated";

export function registerOption() {
  deprecated(
    "`registerOption() from `pretty-text` is deprecated. Use `helper.registerOptions()` instead.",
    {
      since: "2.8.0.beta9",
      id: "discourse.pretty-text.registerOption",
    }
  );
}
