import type { ElementDragPayload } from "@atlaskit/pragmatic-drag-and-drop/adapter/element-adapter";

/**
 * Where the dragged body travels when a source registered a drag handle.
 *
 * The handle is what the underlying library registers, so that the row keeps
 * neither `draggable="true"` nor the unselectable text that attribute brings.
 * The body is the row the handle stands for, and it is what a target reports as
 * `source.element` and compares for `acceptsSelf`.
 */
export const DRAG_BODY = "discourse:dragBody";

/**
 * Resolves the body an element drag represents.
 *
 * @param source - The payload as the underlying library carries it.
 */
export function dragBodyOf(source: ElementDragPayload): Element | null {
  return (source.data?.[DRAG_BODY] as Element) ?? source.element ?? null;
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
 * One value, several, or nothing, as a list.
 *
 * @param value - The `accepts` filter as the consumer supplied it.
 */
export function toAcceptList<T>(value?: T | T[] | null): T[] {
  if (!value) {
    return [];
  }
  if (Array.isArray(value)) {
    return value;
  }
  return [value];
}

/**
 * Whether a drag's type is one the consumer asked for.
 *
 * Centralized so every reader of the type applies the same filter semantics.
 *
 * @param types - One type, several, or nothing at all to match every drag.
 * @param source - The dragged source, compared through {@link dragTypeOf}.
 */
export function matchesDragType(
  types: string | string[] | undefined,
  source: ElementDragPayload
) {
  const list = toAcceptList(types);
  if (list.length === 0) {
    return true;
  }
  return list.includes(dragTypeOf(source.data) as string);
}

/**
 * A drag source as consumers read it: routing keys lifted out and the dragged
 * body in place of the grip that carried it.
 */
export interface NormalizedDragSource {
  /** The source's discriminator, or `null` when the drag carries none. */
  type: string | null;

  /** The payload the source attached to the drag. */
  data: Record<string, unknown>;

  /** The dragged element, or `null` when the drag has none. */
  element: Element | null;
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
  return { type: type as string, data, element: element as HTMLElement };
}

/**
 * Resolves a raw payload into the shape every reader reports.
 *
 * This is the single place the routing vocabulary above is interpreted. The
 * drop target, the monitor modifier, and the service all consume it, so a
 * payload reads identically wherever a consumer meets it.
 *
 * @param source - The payload as the underlying library carries it.
 * @param fallbackElement - Reported as `element` when the drag itself has none;
 *   a drop target passes itself here.
 */
export function normalizeDragSource(
  source: ElementDragPayload,
  fallbackElement?: Element
): NormalizedDragSource {
  // Lifted out first: the body is routing, not payload, so no consumer should
  // ever iterate onto it.
  const data = { ...(source.data ?? {}) };
  delete data[DRAG_BODY];

  return {
    // The underlying library types every payload value as `unknown`, because
    // anything registering a draggable with it can put anything there.
    // `dDragAndDropSource` always stamps its discriminator as a string.
    type: (data.type ?? null) as string | null,
    data,
    // A source that registered a handle publishes the body it stands for, so a
    // consumer receives the element the user is moving rather than the grip
    // they happened to press.
    element: dragBodyOf(source) ?? fallbackElement ?? null,
  };
}
