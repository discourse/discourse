/**
 * DEPRECATED: Do not use LegacyArrayLikeObject for new code.
 *
 * This class is intended ONLY for providing TrackedArray capabilities to support
 * already existing classes that previously used the ArrayProxy mixin. It should not
 * be used in new development.
 *
 * For new code, use a standard class with tracked properties and `@autoTrackedArray` for the content property.
 * Example:
 *
 * ```js
 * import { tracked } from '@glimmer/tracking';
 * import { autoTrackedArray } from "discourse/lib/tracked-tools";
 *
 * class MyArrayWrapper {
 *   @tracked someProp;
 *   @autoTrackedArray content = [];
 * }
 * ```
 *
 * This approach provides reactivity and array capabilities without legacy proxy patterns.
 */

import EmberObject from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import { isTrackedArray } from "discourse/lib/tracked-tools";

/**
 * @deprecated
 *
 * LegacyArrayLikeObject is an EmberObject that keeps its items in a TrackedArray,
 * exposed through the read-only `content` property, next to any other properties and methods.
 *
 * Note: Must be instantiated via LegacyArrayLikeObject.create().
 *
 * @example
 * ```js
 * const obj = LegacyArrayLikeObject.create({ content: [1,2,3], foo: 'bar' });
 * obj.content.push(4);
 * obj.foo // 'bar'
 * ```
 */
export default class LegacyArrayLikeObject<T = unknown> extends EmberObject {
  static #isConstructing = false; // to simulate a private constructor

  /**
   * Creates an instance of LegacyArrayLikeObject. Must be used instead of `new`.
   *
   * @param attrs - Properties applied after subclass fields initialize. `content` must be an array.
   */
  static create<M extends LegacyArrayLikeObject>(
    this: new (...args: never[]) => M,
    attrs?: Partial<M> & Record<string, unknown>
  ): M;

  static create(attrs: { content?: unknown[] } & Record<string, unknown> = {}) {
    LegacyArrayLikeObject.#isConstructing = true;

    const { content, ...properties } = attrs;
    const object = new this(content);

    // Subclass field initializers run after the base constructor and would overwrite these.
    object.setProperties(properties);

    return object;
  }

  #content: T[];

  /**
   * Constructor is private. Use LegacyArrayLikeObject.create() instead.
   *
   * @param content - The array to wrap. Must be an array.
   * @throws `TypeError` if not called via .create or if content is not an array.
   * @internal
   */
  constructor(content: T[] = []) {
    super();

    if (!LegacyArrayLikeObject.#isConstructing) {
      throw new TypeError(
        `${this.constructor.name} is not constructable. Use the static \`${this.constructor.name}.create()\` method instead.`
      );
    }
    LegacyArrayLikeObject.#isConstructing = false;

    // Validate inputs
    if (!Array.isArray(content)) {
      throw new TypeError(
        `${this.constructor.name}: \`.content\` must be an array`
      );
    }

    this.#content = isTrackedArray(content) ? content : trackedArray(content);
  }

  /** The wrapped array. It cannot be replaced, so mutate its elements instead. */
  get content(): T[] {
    return this.#content;
  }
}
