import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { cached, tracked } from "@glimmer/tracking";
import { assert } from "@ember/debug";
import { isDestroying } from "@ember/destroyable";
import Owner, { getOwner } from "@ember/owner";
import { schedule } from "@ember/runloop";
import curryComponent from "ember-curry-component";
import { modifier } from "ember-modifier";
import { revealInScroller } from "discourse/ui-kit/-internals/scroll-strip/reveal";
import DConditionalInElement from "discourse/ui-kit/d-conditional-in-element";
import Tab from "discourse/ui-kit/d-tabs/-internals/parts/tab";
import Tablist from "discourse/ui-kit/d-tabs/-internals/parts/tablist";
import type {
  DTabsBag,
  DTabsEngine,
  DTabsHeaderBag,
  DTabsOrientation,
  DTabsSignature,
} from "discourse/ui-kit/d-tabs/types";
import dUniqueId from "discourse/ui-kit/helpers/d-unique-id";

export type {
  DTabsBag,
  DTabsHeaderBag,
  DTabsOrientation,
  DTabsSignature,
} from "discourse/ui-kit/d-tabs/types";

const NEVER_RENDERED = Symbol("never rendered");

/**
 * An ARIA tabs widget that owns the tab strip, the roving keyboard cursor,
 * the persistent tabpanel, and the ids that pair them. A consumer declares
 * each tab with its label and panel content and supplies the selection.
 *
 * Selection is controlled: `@active` in, `@onActivate` out, and nothing
 * moves until the owner feeds the key back. The component never invents a
 * fallback, because which tab deserves one is the owner's policy.
 * Activation is manual: arrow keys move focus only, and a tab is selected
 * by click, Enter, or Space.
 *
 * A strip wider than its container scrolls rather than wraps, and the
 * selected tab is brought into view without the page moving.
 *
 * The declaration block renders inside the tablist element, wherever that
 * element sits. A `<:header>` block can place the yielded `Tablist` among
 * its own controls; the tabs still land in it.
 *
 * This is the tabs widget: content panels switched in place. Tab-shaped
 * route navigation stays on `DNavItem`, `DHorizontalOverflowNav`, and
 * `DPageHeader`, which render links, not `role="tab"`.
 *
 * ```gjs
 * <DTabs @active={{this.section}} @onActivate={{this.setSection}} @label={{i18n "user.sections"}} as |tabs|>
 *   <tabs.Tab @key="account" @label={{i18n "user.account"}}>
 *     <AccountSettings />
 *   </tabs.Tab>
 *   <tabs.Tab @key="security" @label={{i18n "user.security"}}>
 *     <SecuritySettings />
 *   </tabs.Tab>
 * </DTabs>
 * ```
 */
export default class DTabs extends Component<DTabsSignature> {
  @tracked tablistElement: HTMLElement | null = null;

  registerPanel = modifier((element: HTMLElement) => {
    this.#panelActual = element;
    this.#deferTrackedWrite(() => {
      if (this.#panelActual === element) {
        this._panelElement = element;
      }
    });

    return () => {
      if (this.#panelActual === element) {
        this.#panelActual = null;
      }
      if (this._panelElement === element) {
        this._panelElement = null;
      }
    };
  });

  /**
   * Joins a tab button to the registry and bumps the version on both ends
   * so the keyboard engine reconciles its cursor.
   *
   * The cleanup checks identity. Destructors run deferred, so a replaced
   * button's teardown can land after its successor registered and must not
   * evict it.
   */
  registerTab = modifier((element: Element, [key]: [string]) => {
    if (DEBUG) {
      // A duplicate and a branch replacement not yet torn down look alike
      // here. The post-render scan decides.
      const existing = this.#tabs.get(key);
      if (existing !== undefined && existing !== element) {
        this.#pendingDuplicateChecks.push({
          key,
          first: existing,
          second: element,
        });
      }
      this.#queueStrayContentScan();
    }

    this.#tabs.set(key, element);
    this.#tabKeys.set(element, key);
    // Only the selected tab's own arrival can leave it out of view. Revealing
    // on any registration would drag the strip back while the reader is
    // reading somewhere else in it.
    if (key === this.args.active) {
      this.#queueReveal();
    }
    this.#deferTrackedWrite(() => {
      if (this.#tabs.get(key) === element) {
        this._tabsVersion++;
      }
    });

    return () => {
      if (this.#tabs.get(key) === element) {
        this.#tabs.delete(key);
        // A live @key change tears down and reinstalls inside the tracked
        // update frame, so the bump is deferred like the install's.
        this.#deferTrackedWrite(() => this._tabsVersion++);
      }
    };
  });

  /** Captures the tablist element the declaration block portals into. */
  registerTablist = modifier((element: HTMLElement) => {
    let strayContentObserver: MutationObserver | undefined;
    if (DEBUG) {
      assert(
        "d-tabs: a group renders one Tablist — the <:header> block must place it exactly once",
        this.#tablistActual === null ||
          this.#tablistActual === element ||
          !this.#tablistActual.isConnected
      );
      // Content can enter the tablist without a tab registering. A group
      // whose guard already fired is reported once, not on every mutation
      // of its broken tree.
      strayContentObserver = new MutationObserver(() =>
        this.#queueStrayContentScan()
      );
      strayContentObserver.observe(element, { childList: true });
    }

    this.#tablistActual = element;
    this.#deferTrackedWrite(() => {
      if (this.#tablistActual === element) {
        this.tablistElement = element;
      }
    });

    return () => {
      strayContentObserver?.disconnect();
      if (this.#tablistActual === element) {
        this.#tablistActual = null;
      }
      if (this.tablistElement === element) {
        this.tablistElement = null;
      }
    };
  });

  /**
   * Swap effects keyed on `@active`: reset the panel's scroll and rescue
   * focus when the outgoing content held it.
   *
   * Focus is tracked with listeners, not read at swap time. By then the
   * outgoing content is already gone.
   */
  panelEffects = modifier((element: HTMLElement, [active]: [unknown]) => {
    const onFocusIn = () => (this.#focusWasInPanel = true);
    const onFocusOut = (event: FocusEvent) => {
      if (event.relatedTarget instanceof Node) {
        if (!element.contains(event.relatedTarget)) {
          this.#focusWasInPanel = false;
        }
        return;
      }

      // A null relatedTarget is either a real blur or Chromium removing the
      // focused element. One hop later only the blurred one is still connected.
      const previousTarget = event.target;
      schedule("afterRender", () => {
        if (!(previousTarget instanceof Node)) {
          return;
        }
        if (!previousTarget.isConnected) {
          // Removed by the consumer. A pending swap still rescues, so the
          // flag survives until its destroy effect reads it.
          if (!this.#swapPending) {
            this.#focusWasInPanel = false;
          }
          return;
        }
        if (!element.contains(document.activeElement)) {
          this.#focusWasInPanel = false;
        }
      });
    };
    element.addEventListener("focusin", onFocusIn);
    element.addEventListener("focusout", onFocusOut);

    if (
      this.#lastSwapActive !== NEVER_RENDERED &&
      this.#lastSwapActive !== active
    ) {
      // The outgoing content detaches in the `actions` queue, which the
      // runloop rewinds to after this render. `destroy` is the last queue,
      // so by then focus has already left. Earlier, it still looks held.
      // Being last also means this runs after the incoming content's own
      // effects, so a consumer restoring a per-tab scroll offset on mount
      // must do it after this, not during render.
      this.#swapPending = true;
      schedule("destroy", () => {
        this.#swapPending = false;
        if (isDestroying(this) || !element.isConnected) {
          return;
        }

        element.scrollTop = 0;
        element.scrollLeft = 0;

        // Focus resting on body means the removal dropped it. On a real
        // control, the user moved on.
        if (this.#focusWasInPanel && document.activeElement === document.body) {
          element.focus({ preventScroll: true });
        }
        this.#focusWasInPanel = element.contains(document.activeElement);
      });
    }
    this.#lastSwapActive = active;
    this.#queueReveal();

    return () => {
      element.removeEventListener("focusin", onFocusIn);
      element.removeEventListener("focusout", onFocusOut);
    };
  });
  #uid = dUniqueId();
  #tabs = new Map<string, Element>();

  /**
   * The key each tab element registered under. Read back rather than the
   * `data-d-tab` attribute, which is the same key stringified: a consumer
   * whose ids are not strings would otherwise be handed a different value
   * by the keyboard than by a click.
   */
  #tabKeys = new WeakMap<Element, string>();

  /**
   * Opaque DOM-id suffixes per tab key. Consumer keys cannot go into DOM ids:
   * `aria-labelledby` splits on whitespace, so "account settings" would
   * point at two missing elements.
   */
  #domIdSuffixes = new Map<string, number>();
  #nextDomIdSuffix = 0;

  /**
   * Untracked mirrors written synchronously at modifier install. The tracked
   * twins are written one hop later, because a tracked write from a modifier
   * lands inside the transaction that already read it.
   *
   * The DEBUG guards and the post-render reveal read these, so neither
   * races the deferral.
   */
  #tablistActual: HTMLElement | null = null;
  #panelActual: HTMLElement | null = null;

  /**
   * Whether focus sits inside the tabpanel. Held on the class because the
   * `panelEffects` install closure is torn down and re-run on every
   * `@active` swap, which is exactly when the swap logic needs the value.
   */
  #focusWasInPanel = false;

  /** Whether a swap is between its render and its `destroy` effect. */
  #swapPending = false;

  /** The `@active` the panel effects last saw, to tell swaps from setup. */
  #lastSwapActive: unknown = NEVER_RENDERED;
  #strayScanQueued = false;
  #guardTripped = false;
  #revealQueued = false;

  /** Same-key registrations awaiting the post-render duplicate verdict. */
  #pendingDuplicateChecks: Array<{
    key: string;
    first: Element;
    second: Element;
  }> = [];

  #engine: DTabsEngine = (() => {
    /* eslint-disable-next-line @typescript-eslint/no-this-alias */
    const self = this;

    return {
      get active() {
        return self.args.active;
      },
      get label() {
        return self.args.label;
      },
      get orientation() {
        return self.orientation;
      },
      get hasTabs() {
        return self.hasTabs;
      },
      get panelDomId() {
        return self.panelDomId;
      },
      get panelElement() {
        return self._panelElement;
      },
      get tabsVersion() {
        return self._tabsVersion;
      },
      tabDomIdFor: (key: string) => this.#tabDomIdFor(key),
      activate: (key: string) => this.args.onActivate(key),
      activateFromElement: (item: HTMLElement) => {
        const key = this.#tabKeys.get(item);
        if (key !== undefined) {
          this.args.onActivate(key);
        }
      },
      registerTab: this.registerTab,
      registerTablist: this.registerTablist,
      checkTabLabel: (
        key: string,
        label: string | undefined,
        hasBlock: boolean
      ) => {
        if (DEBUG && (label !== undefined) === hasBlock) {
          this.#guardTripped = true;
          assert(
            `d-tabs: tab "${key}" needs either @label or a <:label> block, and not both`,
            false
          );
        }
      },
    };
  })();
  @tracked _panelElement: HTMLElement | null = null;

  /**
   * Bumped whenever the tab registry changes. The registry is a plain Map, so
   * a getter that reads it must consume this tag to recompute; the `void`
   * reads below are load-bearing, not dead statements.
   */
  @tracked _tabsVersion = 0;

  constructor(owner: Owner, args: DTabsSignature["Args"]) {
    super(owner, args);

    if (DEBUG) {
      assert(
        "d-tabs: @label is required — the tablist needs an accessible name",
        typeof args.label === "string" && args.label.length > 0
      );
      assert(
        "d-tabs: @onActivate is required — selection is controlled by the consumer",
        typeof args.onActivate === "function"
      );

      schedule("afterRender", () => {
        if (isDestroying(this)) {
          return;
        }

        assert(
          "d-tabs: no tablist rendered — a <:header> block must place the yielded Tablist",
          this.#tablistActual !== null
        );
      });
    }
  }

  get orientation(): DTabsOrientation {
    return this.args.orientation ?? "horizontal";
  }

  get hasTabs() {
    void this._tabsVersion;
    return this.#tabs.size > 0;
  }

  get panelDomId() {
    return `d-tabs-${this.#uid}-panel`;
  }

  /**
   * The active tab button's DOM id. `undefined` while `@active` names no
   * registered tab, so the panel never labels itself by a missing element.
   */
  get activeTabDomId() {
    void this._tabsVersion;
    const { active } = this.args;

    if (active === undefined || !this.#tabs.has(active)) {
      return undefined;
    }

    return this.#tabDomIdFor(active);
  }

  /** Names the panel while it has tabs but none of them is selected. */
  get panelAriaLabel() {
    if (this.hasTabs && this.activeTabDomId === undefined) {
      return this.args.label;
    }

    return undefined;
  }

  /**
   * The yielded parts, curried once. Nothing here reads tracked state, so
   * the cache never invalidates and part identity survives re-renders. A
   * new identity would remount every tab's label subtree.
   */
  @cached
  get parts(): { bag: DTabsBag; headerBag: DTabsHeaderBag } {
    const owner = getOwner(this)!;
    const tabs = this.#engine;

    return {
      bag: { Tab: curryComponent(Tab, { tabs }, owner) as DTabsBag["Tab"] },
      headerBag: {
        Tablist: curryComponent(
          Tablist,
          { tabs },
          owner
        ) as DTabsHeaderBag["Tablist"],
      },
    };
  }

  #tabDomIdFor(key: string) {
    let suffix = this.#domIdSuffixes.get(key);
    if (suffix === undefined) {
      suffix = this.#nextDomIdSuffix++;
      this.#domIdSuffixes.set(key, suffix);
    }

    return `d-tabs-${this.#uid}-tab-${suffix}`;
  }

  /**
   * Runs a tracked write after the current render transaction closes. The
   * callback re-checks its own precondition, because a teardown can land
   * between the schedule and the flush.
   */
  #deferTrackedWrite(write: () => void) {
    schedule("afterRender", () => {
      if (isDestroying(this)) {
        return;
      }

      write();
    });
  }

  /** Queues one post-render reveal of the selected tab. */
  #queueReveal() {
    if (this.#revealQueued) {
      return;
    }
    this.#revealQueued = true;

    schedule("afterRender", () => {
      this.#revealQueued = false;
      if (isDestroying(this)) {
        return;
      }

      this.#revealActiveTab();
    });
  }

  /**
   * Scrolls the strip, never the page, until the selected tab is fully
   * inside it.
   */
  #revealActiveTab() {
    const tablist = this.#tablistActual;
    const tab = tablist?.querySelector<HTMLElement>(
      '[role="tab"][aria-selected="true"]'
    );
    if (!tablist || !tab) {
      return;
    }

    revealInScroller(tablist, tab);
  }

  /**
   * Queues one post-render sweep of the tablist for content that is not a
   * tab. Never queued from construction: it must run after the declaration
   * block has actually landed in the tablist. Tab registration queues it,
   * and so do the tablist's own child mutations.
   */
  #queueStrayContentScan() {
    if (this.#strayScanQueued || this.#guardTripped) {
      return;
    }
    this.#strayScanQueued = true;

    schedule("afterRender", () => {
      this.#strayScanQueued = false;
      if (isDestroying(this) || this.#guardTripped || !this.#tablistActual) {
        return;
      }

      try {
        this.#scanDeclaration(this.#tablistActual);
      } catch (error) {
        this.#guardTripped = true;
        throw error;
      }
    });
  }

  #scanDeclaration(tablist: HTMLElement) {
    // By now a branch replacement's predecessor has detached, while a
    // genuine duplicate keeps both claimants attached.
    const pending = this.#pendingDuplicateChecks.splice(0);
    for (const { key, first, second } of pending) {
      assert(
        `d-tabs: duplicate tab key "${key}" — tab keys must be unique within a group`,
        !(first.isConnected && second.isConnected)
      );
    }

    for (const node of tablist.childNodes) {
      // An unregistered role="tab" element is as stray as a div. It would
      // join the keyboard cursor without joining the group. Identity, not the
      // data attribute: the attribute is the key stringified, so a non-string
      // key would fail the lookup and report a stray tab that is not one.
      const registeredKey = node instanceof Element && this.#tabKeys.get(node);
      const isStrayElement =
        node instanceof Element &&
        (node.getAttribute("role") !== "tab" ||
          registeredKey === undefined ||
          this.#tabs.get(registeredKey) !== node);
      const isStrayText =
        node.nodeType === Node.TEXT_NODE &&
        (node.textContent ?? "").trim() !== "";

      assert(
        "d-tabs: the declaration block may contain only tab declarations — found unexpected content in the tablist",
        !isStrayElement && !isStrayText
      );
    }
  }

  <template>
    <div class="d-tabs" ...attributes>
      {{#if (has-block "header")}}
        {{yield this.parts.headerBag to="header"}}
      {{else}}
        <div class="d-tabs__strip"><this.parts.headerBag.Tablist /></div>
      {{/if}}

      <div
        aria-label={{this.panelAriaLabel}}
        aria-labelledby={{this.activeTabDomId}}
        class="d-tabs__panel"
        id={{this.panelDomId}}
        role={{if this.hasTabs "tabpanel"}}
        tabindex={{if this.hasTabs "0"}}
        {{this.registerPanel}}
        {{this.panelEffects @active}}
      ></div>

      <DConditionalInElement @element={{this.tablistElement}}>
        {{yield this.parts.bag}}
      </DConditionalInElement>
    </div>
  </template>
}
