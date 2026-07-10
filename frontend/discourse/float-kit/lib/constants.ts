import type { AutoUpdateOptions, ReferenceElement } from "@floating-ui/dom";
import { type ComponentLike } from "@glint/template";
import DDefaultToast from "discourse/float-kit/components/d-default-toast";

/**
 * The placements floating-ui may position a float at, ordered by preference. Kept
 * `as const` so consumers can derive the exact string-literal union (see
 * `FloatUiPlacement`) instead of a loose `string`.
 */
export const FLOAT_UI_PLACEMENTS = [
  "top",
  "top-start",
  "top-end",
  "right",
  "right-start",
  "right-end",
  "bottom",
  "bottom-start",
  "bottom-end",
  "left",
  "left-start",
  "left-end",
] as const;

/**
 * The strategies that keep a float on screen when its preferred placement would
 * overflow. `FLIP` flips to the opposite side, `AUTO_PLACEMENT` picks the best fit,
 * and `NONE` disables the optimizer entirely.
 */
export const VISIBILITY_OPTIMIZERS = {
  FLIP: "flip",
  AUTO_PLACEMENT: "autoPlacement",
  NONE: "none",
} as const;

/**
 * The reference a float is anchored to: either a real element or a virtual one — any
 * object implementing `getBoundingClientRect` (floating-ui's `ReferenceElement`). The
 * listener and focus code only runs against real elements (see `triggerElement`).
 */
export type FloatKitTrigger = ReferenceElement;

/** One of the placements in `FLOAT_UI_PLACEMENTS`. */
export type FloatUiPlacement = (typeof FLOAT_UI_PLACEMENTS)[number];

/** One of the visibility-optimizer identifiers in `VISIBILITY_OPTIMIZERS`. */
export type VisibilityOptimizer =
  (typeof VISIBILITY_OPTIMIZERS)[keyof typeof VISIBILITY_OPTIMIZERS];

/**
 * A relayed lifecycle or trigger callback (`onShow`, `onClose`, `beforeTrigger`, …).
 * These are handed straight to consumers that pass functions of varying arity and
 * return type, so the signature is deliberately broad-but-real: it accepts any
 * function, still documents intent, and type-checks the internal call — unlike the
 * bare `Function` type (which yields an unchecked `any` and trips lint).
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any -- a relay callback must accept consumer functions of any argument shape; `unknown[]` would reject them.
export type FloatCallback = (...args: any[]) => void;

/**
 * The events that open (or close) a float. Either a single list applied on every
 * viewport, or a split of `mobile`/`desktop` lists resolved against the current view.
 */
export type FloatTriggers = string[] | { mobile: string[]; desktop: string[] };

/**
 * The full set of options shared by menus and tooltips, after a consumer's partial
 * options have been merged over the defaults below. This is the source of truth for
 * the corresponding component arguments; every field is always present on an
 * instance because the defaults populate it.
 */
export interface TooltipOptions {
  animated: boolean;

  /** Whether to render a directional arrow pointing at the trigger. */
  arrow: boolean;

  /** Read by the shared float body to decide whether to focus it; menus set it, tooltips leave it unset. */
  autofocus?: boolean;

  /** Read by the shared inline float to render as a modal on mobile; menus set it, tooltips leave it unset. */
  modalForMobile?: boolean;

  beforeTrigger: FloatCallback | null;
  closeOnClickOutside: boolean;
  closeOnEscape: boolean;
  closeOnScroll: boolean;

  /** A component rendered as the content; it receives the `@data` and `@close` arguments. */
  component: ComponentLike<{
    Args: { data?: unknown; close?: FloatCallback };
  }> | null;

  /** The content rendered when neither a block nor a `component` is provided. */
  content: string | null;

  /**
   * Sets a `data-identifier` attribute on both the trigger and the content. Several
   * floats may share an identifier, but only one per identifier is open at a time.
   */
  identifier: string | null;

  /** Improves positioning for a trigger that spans multiple lines. */
  inline: boolean | null;

  interactive: boolean;
  listeners: boolean;

  /** The maximum width of the content, in pixels. */
  maxWidth: number;

  /** Passed as the `@data` argument to a `component` rendered as the content. */
  data: unknown;

  /** Displaces the content from its trigger, in pixels. */
  offset: number;

  triggers: FloatTriggers;
  untriggers: FloatTriggers;
  placement: FloatUiPlacement;
  shiftBeforeVisibilityOptimizer: boolean;
  visibilityOptimizer: VisibilityOptimizer;
  fallbackPlacements: readonly FloatUiPlacement[];
  autoUpdate: boolean | AutoUpdateOptions;
  trapTab: boolean;
  onClose: FloatCallback | null;
  onShow: FloatCallback | null;
  onRegisterApi: FloatCallback | null;
  portalOutletElement: HTMLElement | null;
}

/**
 * The options for a menu: every tooltip option plus the menu-only extras (focus
 * management, the mobile modal, identifier grouping, and the class/width overrides
 * the menu template forwards to its trigger and content).
 */
export interface MenuOptions extends TooltipOptions {
  autofocus: boolean;
  modalForMobile: boolean;

  /** Only one menu per group identifier is open at a time. */
  groupIdentifier: string | null;

  parentIdentifier: string | null;
  triggerClass: string | null;
  contentClass: string | null;
  class: string | null;
  matchTriggerMinWidth: boolean;
  matchTriggerWidth: boolean;
}

/** One action button rendered by the default toast. */
export interface ToastAction {
  action?: (args: { data?: ToastData; close?: FloatCallback }) => void;
  icon?: string;
  label?: string;
  class?: string;
}

/**
 * The `@data` passed to a toast component. The default toast reads these fields;
 * custom components may add their own (hence the index signature).
 */
export interface ToastData {
  theme?: string;
  icon?: string;
  title?: string;
  message?: string;
  isHtmlMessage?: boolean;
  actions?: ToastAction[];
  [key: string]: unknown;
}

/** The signature of a toast component (the default is `DDefaultToast`). */
export type ToastComponent = ComponentLike<{
  Element: HTMLElement;
  Args: {
    data?: ToastData;
    close?: FloatCallback;
    showProgressBar?: boolean;
    onRegisterProgressBar?: (element: HTMLElement) => void;
  };
}>;

/** The options for a toast, after merging over the defaults below. */
export interface ToastOptions {
  autoClose: boolean;
  autoUpdate: boolean | AutoUpdateOptions;
  duration: "short" | "long" | number;
  component: ToastComponent;
  showProgressBar: boolean;
  views: Array<"desktop" | "mobile">;

  /** The `@data` passed to the toast component. */
  data?: ToastData;

  /** A class added to the toast element. */
  class?: string;
}

export const TOOLTIP: { options: TooltipOptions; portalOutletId: string } = {
  options: {
    animated: true,
    arrow: true,
    beforeTrigger: null,
    closeOnClickOutside: true,
    closeOnEscape: true,
    closeOnScroll: true,
    component: null,
    content: null,
    identifier: null,
    inline: null,
    interactive: false,
    listeners: false,
    maxWidth: 350,
    data: null,
    offset: 10,
    triggers: { mobile: ["click"], desktop: ["hover", "click"] },
    untriggers: { mobile: ["click"], desktop: ["hover", "click"] },
    placement: "top",
    shiftBeforeVisibilityOptimizer: false,
    visibilityOptimizer: VISIBILITY_OPTIMIZERS.FLIP,
    fallbackPlacements: FLOAT_UI_PLACEMENTS,
    autoUpdate: true,
    trapTab: true,
    onClose: null,
    onShow: null,
    onRegisterApi: null,
    portalOutletElement: null,
  },
  portalOutletId: "d-tooltip-portal-outlet",
};

export const MENU: { options: MenuOptions; portalOutletId: string } = {
  options: {
    animated: true,
    arrow: false,
    autofocus: false,
    beforeTrigger: null,
    closeOnEscape: true,
    closeOnClickOutside: true,
    closeOnScroll: false,
    component: null,
    content: null,
    identifier: null,
    interactive: true,
    listeners: false,
    maxWidth: 400,
    data: null,
    offset: 10,
    triggers: ["click"],
    untriggers: ["click"],
    placement: "bottom-start",
    shiftBeforeVisibilityOptimizer: false,
    visibilityOptimizer: VISIBILITY_OPTIMIZERS.FLIP,
    fallbackPlacements: FLOAT_UI_PLACEMENTS,
    autoUpdate: true,
    trapTab: true,
    onClose: null,
    onShow: null,
    onRegisterApi: null,
    modalForMobile: false,
    inline: null,
    groupIdentifier: null,
    parentIdentifier: null,
    triggerClass: null,
    contentClass: null,
    class: null,
    matchTriggerMinWidth: false,
    matchTriggerWidth: false,
    portalOutletElement: null,
  },
  portalOutletId: "d-menu-portal-outlet",
};

export const TOAST: { options: ToastOptions } = {
  options: {
    autoClose: true,
    autoUpdate: { ancestorScroll: false },
    duration: "short",
    component: DDefaultToast,
    showProgressBar: false,
    views: ["desktop", "mobile"],
  },
};
