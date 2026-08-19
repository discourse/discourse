import type { ElementDragPayload } from "@atlaskit/pragmatic-drag-and-drop/adapter/element-adapter";
import type { ExternalDragPayload } from "discourse/lib/-internals/drag-and-drop/external-vocabulary";
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
 * The routing type carried by a browser-started drag after adoption.
 *
 * Namespaced because it shares the same field as consumer-defined types. It
 * must remain a string because the drag library's routing data crosses the same
 * public surface as ordinary source data.
 */
export const ADOPTED_DRAG_TYPE = "discourse:adopted-native-drag";

/** Where an adoption's consumer-facing type travels beside the routing type. */
export const ADOPTED_AS = "adoptedAs";

/**
 * The type a drag answers to in an `accepts` / `types` filter.
 *
 * For an adopted drag this is the adoption's declared type, not the internal
 * routing type, so consumers filter on their own vocabulary either way.
 *
 * @param data - A drag payload's `data`, as the underlying library carries it.
 */
export function dragTypeOf(data?: Record<string, unknown>) {
  if (data?.type === ADOPTED_DRAG_TYPE) {
    return data[ADOPTED_AS] as string | undefined;
  }
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
 * A drag source as consumers read it: routing keys removed, the type resolved
 * through the adoption, and the dragged body in place of the handle that
 * carried it.
 */
export interface NormalizedDragSource {
  /** The source's discriminator, or `null` when the drag carries none. */
  type: string | null;

  /** The payload the source or adoption attached to the drag. */
  data: Record<string, unknown>;

  /** The dragged element: the published body, else the registered element. */
  element: HTMLElement;

  /**
   * The snapshotted native payload for an adopted drag. Absent for registered
   * element sources.
   */
  native?: ExternalDragPayload;
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
  const { [DRAG_BODY]: body, ...data } = source.data ?? {};
  const adopted = data.type === ADOPTED_DRAG_TYPE;
  // The reserved keys route an adopted drag. A consumer iterating `data` must
  // not meet them.
  const { [ADOPTED_AS]: adoptedAs, native, ...consumerData } = data;
  delete consumerData.type;

  return {
    // The library types payload values as `unknown`; owned sources always stamp
    // a string `type` and the adoption its sentinel.
    type: (adopted ? adoptedAs : (data.type ?? null)) as string | null,
    data: adopted ? consumerData : data,
    element: (body as HTMLElement | undefined) ?? source.element,
    ...(adopted ? { native: native as ExternalDragPayload } : {}),
  };
}
