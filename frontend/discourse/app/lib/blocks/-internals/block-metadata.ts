import type { BlockMetadata } from "discourse/blocks/types";

/**
 * Maps block classes to their metadata. A WeakMap ensures classes are garbage
 * collected when no longer referenced and that authorization state cannot be
 * discovered via `Object.getOwnPropertySymbols()`. The key is widened to
 * `object` (rather than a block-class type) because the registry probes it with
 * lazy block factory functions too, and both classes and factories are objects.
 *
 * Kept in a module with no runtime imports: the error helpers read it, and the
 * decorator that writes it imports those helpers, so housing it with the
 * decorator would close an import cycle.
 */
export const blockMetadataMap = new WeakMap<object, BlockMetadata>();

/**
 * Gets all metadata for a component registered with `@block`.
 *
 * @experimental This API is under active development and may change or be
 * removed in future releases without prior notice.
 *
 * @param component - The component (or factory) to get metadata for. Accepts
 *   nullish values so untyped registration paths can probe safely.
 * @returns The block metadata object, or `null` if not a block.
 */
export function getBlockMetadata(
  component: object | null | undefined
): BlockMetadata | null {
  return component ? (blockMetadataMap.get(component) ?? null) : null;
}
