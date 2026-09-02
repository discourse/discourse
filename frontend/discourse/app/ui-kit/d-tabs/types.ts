import type { ComponentLike, ModifierLike } from "@glint/template";

/** Navigation axis of the tab strip. A tablist is one-dimensional. */
export type DTabsOrientation = "horizontal" | "vertical";

/**
 * The live state and controls one `DTabs` instance shares with its parts.
 *
 * Internal contract between the core and its `-internals` parts; consumers
 * never see it because the curried parts erase the `tabs` argument.
 */
export interface DTabsEngine {
  /** The controlled active tab id, read live from the core's args. */
  readonly active: string | undefined;

  /** The tablist's accessible name, read live from the core's args. */
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
 * Typed as the CONSUMER surface — the curried engine argument is omitted
 * outright rather than merely optional, so a consumer cannot cross-wire a
 * tab into another group's registry through the type system.
 */
export interface DTabsBag {
  /** Declares one tab: its strip button and its panel content together. */
  Tab: ComponentLike<{
    Element: HTMLButtonElement;
    Args: { id: string; label?: string; disabled?: boolean };
    Blocks: { default: []; label: [] };
  }>;
}

/** What the `<:header>` block receives: the placeable tablist. */
export interface DTabsHeaderBag {
  /**
   * The real tablist element, pre-wired with the keyboard engine. A header
   * block must place it exactly once; the tab buttons render inside it.
   */
  Tablist: ComponentLike<{ Element: HTMLDivElement }>;
}

export interface DTabsSignature {
  /** The widget root: a column of the strip row and the persistent panel. */
  Element: HTMLDivElement;
  Args: {
    /**
     * The id of the selected tab. Controlled only: the component holds no
     * selection state and never picks a fallback. `undefined`, or an id no
     * declared tab carries, selects nothing and leaves the panel empty.
     */
    active: string | undefined;

    /**
     * Called with the id of the tab the user activates, through click,
     * Enter, or Space. Nothing changes until the owner feeds the id back
     * through `@active`.
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
     * Replaces the default strip row. The block lays out its own row and
     * must place the yielded `Tablist` part, which carries the tabs, the
     * keyboard surface, and the ARIA container all at once. With this
     * block present, the tabs move to an explicit `<:default>` block.
     */
    header: [header: DTabsHeaderBag];
  };
}

export interface DTabsTabSignature {
  /** The real tab button; splattributes and modifiers land on it. */
  Element: HTMLButtonElement;
  Args: {
    /** The engine of the owning group, curried by the core. */
    tabs: DTabsEngine;

    /** Stable identity for selection and DOM id derivation. Unique. */
    id: string;

    /**
     * The button's text. Exactly one of this and the `<:label>` block must
     * be given.
     */
    label?: string;

    /**
     * Announces the tab as unavailable while keeping it focusable, so it
     * stays discoverable; it is never activated.
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

export interface DTabsTablistSignature {
  /** The tablist element itself; splattributes land on it. */
  Element: HTMLDivElement;
  Args: {
    /** The engine of the owning group, curried by the core. */
    tabs: DTabsEngine;
  };
}
