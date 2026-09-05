import type { ComponentLike, ModifierLike } from "@glint/template";

/** The arrow-key axis of the tab strip. */
export type DTabsOrientation = "horizontal" | "vertical";

/**
 * The live state and controls one `DTabs` instance shares with its parts.
 *
 * Internal contract between the core and its `-internals` parts; consumers
 * never see it because the curried parts erase the `tabs` argument.
 */
export interface DTabsEngine {
  /** The controlled active tab id. */
  readonly active: string | undefined;

  /** The tablist's accessible name. */
  readonly label: string;

  /** The resolved orientation, defaulted to `"horizontal"`. */
  readonly orientation: DTabsOrientation;

  /** Whether any tab is currently registered. */
  readonly hasTabs: boolean;

  /** The persistent tabpanel's DOM id, minted once per instance. */
  readonly panelDomId: string;

  /** The persistent tabpanel element, once it has rendered. */
  readonly panelElement: HTMLElement | null;

  /** Reactivity key that changes whenever the registered tab set does. */
  readonly tabsVersion: number;

  /** Derives the DOM id a tab with the given id renders under. */
  tabDomIdFor(id: string): string;

  /** Requests activation of the given tab through the consumer's callback. */
  activate(id: string): void;

  /** Bridges the roving-focus engine's element reports back to tab ids. */
  activateFromElement(item: HTMLElement): void;

  /** Element modifier a tab button applies to join the registry. */
  registerTab: ModifierLike<{
    Element: HTMLElement;
    Args: { Positional: [id: string] };
  }>;

  /** Element modifier the tablist part applies to become the portal target. */
  registerTablist: ModifierLike<{
    Element: HTMLElement;
    Args: { Positional: [] };
  }>;

  /** Asserts in DEBUG that exactly one of `@label` and the `<:label>` block was given. */
  checkTabLabel(id: string, label: string | undefined, hasBlock: boolean): void;
}

/**
 * What the default block receives: the tab declaration part.
 *
 * Typed as the consumer surface. The curried engine argument is omitted,
 * not optional, so a consumer cannot wire a tab into another group's
 * registry.
 */
export interface DTabsBag {
  /** Declares one tab: its strip button and its panel content together. */
  Tab: ComponentLike<{
    Element: DTabsTabSignature["Element"];
    Args: Omit<DTabsTabSignature["Args"], "tabs">;
    Blocks: DTabsTabSignature["Blocks"];
  }>;
}

/** What the `<:header>` block receives: the placeable tablist. */
export interface DTabsHeaderBag {
  /**
   * The real tablist element, pre-wired with the keyboard engine. A header
   * block must place it exactly once and keep it in that place: moving it
   * between branches remounts every tab and the active panel content.
   */
  Tablist: ComponentLike<{ Element: DTabsTablistSignature["Element"] }>;
}

export interface DTabsSignature {
  /** The widget root: a column of the strip row and the persistent panel. */
  Element: HTMLDivElement;
  Args: {
    /**
     * The id of the selected tab. Controlled only: the component holds no
     * selection state and never picks a fallback. `undefined`, or an id no
     * declared tab carries, selects nothing and leaves the panel empty. The
     * argument is required, so a typed consumer with nothing selected
     * passes `undefined` explicitly.
     */
    active: string | undefined;

    /**
     * Called with the id of the tab the user activates. Activation is
     * manual: arrow keys only move focus, and a tab is selected by click,
     * Enter, or Space.
     */
    onActivate: (id: string) => void;

    /**
     * The tablist's accessible name, already translated. Required: an
     * unnamed tablist is announced as an anonymous group.
     */
    label: string;

    /**
     * The arrow-key axis. `"vertical"` also announces the orientation,
     * which assistive technology otherwise assumes horizontal.
     */
    orientation?: DTabsOrientation;
  };
  Blocks: {
    /**
     * The tabs, declared as `Tab` children in display order. The block
     * renders inside the tablist element, so it may contain only tab
     * declarations and the control flow around them.
     */
    default: [tabs: DTabsBag];

    /**
     * Replaces the default strip row. The block must place the yielded
     * `Tablist` exactly once; the tabs render inside it. With this block
     * present, the tabs go in an explicit `<:default>` block.
     */
    header: [header: DTabsHeaderBag];
  };
}

/** The signature of the curried `Tab` part. */
export interface DTabsTabSignature {
  /** The real tab button; splattributes and modifiers land on it. */
  Element: HTMLButtonElement;
  Args: {
    /** The engine of the owning group, curried by the core. */
    tabs: DTabsEngine;

    /** Stable identity for selection and DOM ids. Unique within the group. */
    id: string;

    /**
     * The button's text. Exactly one of this and the `<:label>` block must
     * be given.
     */
    label?: string;

    /**
     * Announces the tab as unavailable. It stays focusable so it stays
     * discoverable, but it never activates.
     */
    disabled?: boolean;
  };
  Blocks: {
    /** The panel content, mounted only while this tab is active. */
    default: [];

    /** Arbitrary label content, rendered inside the button. */
    label: [];
  };
}

/** The signature of the curried `Tablist` part. */
export interface DTabsTablistSignature {
  /** The tablist element itself; splattributes land on it. */
  Element: HTMLDivElement;
  Args: {
    /** The engine of the owning group, curried by the core. */
    tabs: DTabsEngine;
  };
}
