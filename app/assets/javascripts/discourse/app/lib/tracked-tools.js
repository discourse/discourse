import { tracked } from "@glimmer/tracking";

/**
 * Define a tracked property on an object without needing to the @tracked decorator.
 * Useful when meta-programming the creation of properties on an object.
 *
 * This must be run before the property is first accessed, so it normally makes sense for
 * this to only be called from a constructor.
 */
export function defineTrackedProperty(target, key, value) {
  Object.defineProperty(
    target,
    key,
    tracked(target, key, { enumerable: true, value })
  );
}
