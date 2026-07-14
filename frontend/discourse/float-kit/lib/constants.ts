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
  /** Whether to animate the float as it opens and closes. */
  animated: boolean;

  /** Whether to render a directional arrow pointing at the trigger. */
  arrow: boolean;

  /** Read by the shared float body to decide whether to focus it; menus set it, tooltips leave it unset. */
  autofocus?: boolean;

  /** Read by the shared inline float to render as a modal on mobile; menus set it, tooltips leave it unset. */
  modalForMobile?: boolean;

  /** Called just before the float is shown. */
  beforeTrigger: FloatCallback | null;

  /** Whether a click outside the float closes it. */
  closeOnClickOutside: boolean;

  /** Whether pressing Escape closes the float. */
  closeOnEscape: boolean;

  /** Whether scrolling closes the float. */
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

  /** Whether the content stays open while the pointer moves into it, so it can be interacted with. */
  interactive: boolean;

  /** Whether FloatKit attaches the trigger event listeners itself, rather than the caller driving it through the service API. */
  listeners: boolean;

  /** The maximum width of the content, in pixels. */
  maxWidth: number;

  /** Passed as the `@data` argument to a `component` rendered as the content. */
  data: unknown;

  /** Displaces the content from its trigger, in pixels. */
  offset: number;

  /** The events that open the float. */
  triggers: FloatTriggers;

  /** The events that close the float. */
  untriggers: FloatTriggers;

  /** The preferred placement of the float relative to its trigger. */
  placement: FloatUiPlacement;

  /** Whether to shift the float into view before running the visibility optimizer, rather than after. */
  shiftBeforeVisibilityOptimizer: boolean;

  /** The strategy that keeps the float on screen when its preferred placement would overflow. */
  visibilityOptimizer: VisibilityOptimizer;

  /** The placements to try, in order, when the preferred one does not fit. */
  fallbackPlacements: readonly FloatUiPlacement[];

  /** Whether to reposition automatically as the trigger or viewport changes; an object passes floating-ui `autoUpdate` options. */
  autoUpdate: boolean | AutoUpdateOptions;

  /** Whether to trap Tab focus within the content. */
  trapTab: boolean;

  /** Called after the float closes. */
  onClose: FloatCallback | null;

  /** Called after the float shows. */
  onShow: FloatCallback | null;

  /** Called with the float instance when it is created, so callers can control it programmatically. */
  onRegisterApi: FloatCallback | null;

  /** The element to render the content into, instead of the default portal outlet. */
  portalOutletElement: HTMLElement | null;
}

/**
 * The options for a menu: every tooltip option plus the menu-only extras (focus
 * management, the mobile modal, identifier grouping, and the class/width overrides
 * the menu template forwards to its trigger and content).
 */
export interface MenuOptions extends TooltipOptions {
  /** Whether to focus the content when the menu opens. */
  autofocus: boolean;

  /** Whether the menu renders as a modal on mobile. */
  modalForMobile: boolean;

  /** Only one menu per group identifier is open at a time. */
  groupIdentifier: string | null;

  /** The identifier of the parent menu, for nested menus. */
  parentIdentifier: string | null;

  /** A class added to the trigger. */
  triggerClass: string | null;

  /** A class added to the content. */
  contentClass: string | null;

  /** A class added to both the trigger and the content. */
  class: string | null;

  /** Whether to set the content's min-width to the trigger's width. */
  matchTriggerMinWidth: boolean;

  /** Whether to set the content's width to the trigger's width. */
  matchTriggerWidth: boolean;
}

/** One action button rendered by the default toast. */
export interface ToastAction {
  /** Called when the button is clicked, receiving the toast data and a close function. */
  action?: (args: { data?: ToastData; close?: FloatCallback }) => void;

  /** The icon ID for the button. */
  icon?: string;

  /** The label for the button. */
  label?: string;

  /** A class added to the button. */
  class?: string;
}

/**
 * The `@data` passed to a toast component. The default toast reads these fields;
 * custom components may add their own (hence the index signature).
 */
export interface ToastData {
  /** A theme name applied to the toast (e.g. `"success"`, `"error"`). */
  theme?: string;

  /** The icon ID shown in the toast. */
  icon?: string;

  /** The toast title. */
  title?: string;

  /** The toast message. */
  message?: string;

  /** Whether `message` is trusted HTML rather than plain text. */
  isHtmlMessage?: boolean;

  /** The action buttons shown in the toast. */
  actions?: ToastAction[];

  [key: string]: unknown;
}

/** The arguments a toast component receives (the default is `DDefaultToast`). */
export interface ToastComponentArgs {
  /** The data to render in the toast. */
  data?: ToastData;

  /** Closes the toast. */
  close?: FloatCallback;

  /** Whether to show a progress bar counting down to auto-close. */
  showProgressBar?: boolean;

  /** Registers the progress-bar element so the auto-close modifier can animate it. */
  onRegisterProgressBar?: (element: HTMLElement) => void;
}

/** The signature of a toast component (the default is `DDefaultToast`). */
export type ToastComponent = ComponentLike<{
  Element: HTMLElement;
  Args: ToastComponentArgs;
}>;

/** The options for a toast, after merging over the defaults below. */
export interface ToastOptions {
  /** Whether the toast closes automatically after `duration`. */
  autoClose: boolean;

  /** Whether to reposition automatically; an object passes floating-ui `autoUpdate` options. */
  autoUpdate: boolean | AutoUpdateOptions;

  /** How long the toast stays open: a preset (`"short"`/`"long"`) or a number of milliseconds. */
  duration: "short" | "long" | number;

  /** The component rendered as the toast body. */
  component: ToastComponent;

  /** Whether to show a progress bar counting down to auto-close. */
  showProgressBar: boolean;

  /** The viewports the toast is shown on. */
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
