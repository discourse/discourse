import { getComponentTemplate } from "@glimmer/manager";

/**
 * Returns whether a value is a renderable component — a component class or a
 * template-only component — as opposed to a plain value, object, or function.
 *
 * Detection is based on the value having an associated component template
 * (`getComponentTemplate`), which both class-backed and template-only
 * components carry. This is more reliable than inferring componenthood by
 * elimination (e.g. "not a string, not a plain object").
 *
 * The `@glimmer/manager` specifier only resolves inside the core bundle, so
 * this helper exists to give plugins and themes a stable, importable way to run
 * the same check without reaching for that internal package themselves.
 *
 * @param {*} value - The value to test.
 * @returns {boolean} `true` when the value is a component, otherwise `false`.
 */
export default function isComponent(value) {
  if (value == null) {
    return false;
  }

  const type = typeof value;
  if (type !== "function" && type !== "object") {
    return false;
  }

  return getComponentTemplate(value) != null;
}
