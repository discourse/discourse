import type { ElementDragPayload } from "@atlaskit/pragmatic-drag-and-drop/adapter/element-adapter";
import { makeArray } from "discourse/lib/helpers";

/**
 * Payload key under which a source registered through a drag handle publishes
 * the element the handle stands for. Targets report that body as
 * `source.element` and compare it for `acceptsSelf`.
 */
export const DRAG_BODY = "discourse:dragBody";

/**
 * Resolves the body an element drag represents.
 *
 * @param source - The payload as the underlying library carries it.
 */
export function dragBodyOf(source: ElementDragPayload): HTMLElement {
  return (
    (source.data?.[DRAG_BODY] as HTMLElement | undefined) ?? source.element
  );
}

/**
 * The type a drag answers to in an `accepts` / `types` filter.
 *
 * @param data - A drag payload's `data`, as the underlying library carries it.
 */
export function dragTypeOf(data?: Record<string, unknown>) {
  return data?.type as string | undefined;
}

/**
 * Whether a drag's type is one the consumer asked for.
 *
 * @param types - One type, several, or nothing at all to match every drag.
 * @param source - The dragged source, compared through {@link dragTypeOf}.
 */
export function matchesDragType(
  types: string | string[] | undefined,
  source: ElementDragPayload
) {
  const list = makeArray(types);
  if (list.length === 0) {
    return true;
  }
  return list.includes(dragTypeOf(source.data) as string);
}

/**
 * A drag source as consumers read it: routing keys removed and the dragged
 * body in place of the handle that carried it.
 */
export interface NormalizedDragSource {
  /** The source's discriminator, or `null` when the drag carries none. */
  type: string | null;

  /** The payload the source attached to the drag. */
  data: Record<string, unknown>;

  /** The dragged element: the published body, else the registered element. */
  element: HTMLElement;
}

/**
 * Normalizes a payload stamped by `dDragAndDropSource`.
 *
 * Unlike arbitrary element drags, an owned payload always carries a string
 * discriminator and an HTML body.
 *
 * @param source - The owned payload as the underlying library carries it.
 */
export function normalizeOwnedDragSource(source: ElementDragPayload): {
  /** The discriminator stamped by the source. */
  type: string;

  /** The consumer payload, including its discriminator. */
  data: Record<string, unknown>;

  /** The dragged body, rather than a handle registered on its behalf. */
  element: HTMLElement;
} {
  const { type, data, element } = normalizeDragSource(source);
  return { type: type as string, data, element };
}

/**
 * Resolves a raw payload into the shape every reader reports.
 *
 * @param source - The payload as the underlying library carries it.
 */
export function normalizeDragSource(
  source: ElementDragPayload
): NormalizedDragSource {
  const data = { ...(source.data ?? {}) };
  delete data[DRAG_BODY];

  return {
    // The library types payload values as `unknown`; owned sources always stamp
    // a string `type`.
    type: (data.type ?? null) as string | null,
    data,
    element: dragBodyOf(source),
  };
}
