/** The viewport edges a docked panel can be moved to, in picker order. */
export const SIDES = ["start", "end", "bottom"] as const;

/** A viewport edge the panel can dock against. */
export type DockSide = (typeof SIDES)[number];
