/**
 * The axis a gesture runs along, shared by every primitive that takes one:
 * the pointer or content moves along it, whether that is a resize, a scroll,
 * or the midpoint a drop is measured against.
 */
export type Axis = "vertical" | "horizontal";

/**
 * A logical side of a box along an axis, resolved against the writing
 * direction rather than a physical edge.
 */
export type Side = "start" | "end";
