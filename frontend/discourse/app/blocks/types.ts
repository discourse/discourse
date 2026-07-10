import type { ComponentLike } from "@glint/template";

/**
 * The data-region boundary the framework curries onto a data-driven block as
 * `@Data`. A block wraps the data-dependent part of its template in `<@Data>`
 * and supplies the named blocks below; the framework paints the loading
 * skeleton and inline error by default.
 *
 * The `Value` type parameter is the shape the block's `data.resolve` produces,
 * so `<:content as |value|>` is typed for the specific block.
 *
 * @typeParam Value - The resolved data yielded to the `content` block.
 */
export type BlockDataComponent<Value = unknown> = ComponentLike<{
  Blocks: {
    content: [value: Value];
    loading: [];
    error: [];
    empty: [];
  };
}>;
