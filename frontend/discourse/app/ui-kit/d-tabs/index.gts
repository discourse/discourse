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

const NEVER_RENDERED = Symbol("never rendered");

/**
 * An in-place ARIA tabs widget that owns the whole interaction: the tab
 * strip, the roving keyboard cursor, the persistent tabpanel, and every id
 * that pairs them. A consumer declares its tabs — label and panel content
 * together — and supplies the selection.
 *
 * Selection is controlled: `@active` in, `@onActivate` out, and nothing
 * moves until the owner feeds the id back. The component never invents a
 * fallback, because which tab deserves one is the owner's policy.
 *
 * The declaration block renders inside the tablist element, wherever that
 * element is: the default strip row, or a spot the consumer chose by
 * placing the yielded `Tablist` from a `<:header>` block. That is what
 * lets a host place its own controls in the strip row without the tabs
 * ever leaving their container.
 *
 * This is the tabs *widget* — content panels switched in place. Tab-shaped
 * route navigation stays on `DNavItem`, `DHorizontalOverflowNav`, and
 * `DPageHeader`, which render links, not `role="tab"`.
 *
 * ```gjs
 * <DTabs @active={{this.section}} @onActivate={{this.setSection}} @label={{i18n "user.sections"}} as |tabs|>
 *   <tabs.Tab @id="account" @label={{i18n "user.account"}}>
 *     <AccountSettings />
 *   </tabs.Tab>
 *   <tabs.Tab @id="security" @label={{i18n "user.security"}}>
 *     <SecuritySettings />
 *   </tabs.Tab>
 * </DTabs>
 * ```
 */
export default class DTabs extends Component<DTabsSignature> {
  @tracked tablistElement: HTMLElement | null = null;

  /** Captures the persistent tabpanel element for the tabs' content portal. */
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
   * Joins a tab button to the registry. The cleanup is identity-guarded:
   * destructors are deferred, so a replaced button's teardown can run after
   * its successor registered, and must not evict it. Both directions bump
   * the version so the keyboard engine reconciles its cursor.
   */
  registerTab = modifier((element: Element, [id]: [string]) => {
    if (DEBUG) {
      // A duplicate and a not-yet-torn-down branch replacement look alike
      // here; the post-render scan decides.
      const existing = this.#tabs.get(id);
      if (existing !== undefined && existing !== element) {
        this.#pendingDuplicateChecks.push({
          id,
          first: existing,
          second: element,
        });
      }
      this.#queueStrayContentScan();
    }

    this.#tabs.set(id, element);
    this.#queueReveal();
    this.#deferTrackedWrite(() => {
      if (this.#tabs.get(id) === element) {
        this._tabsVersion++;
      }
    });

    return () => {
      if (this.#tabs.get(id) === element) {
        this.#tabs.delete(id);
        this._tabsVersion++;
      }
    };
  });

  /**
   * Captures the tablist element the declaration block portals into. The
   * same identity guard as the tabs: an old element's deferred cleanup must
   * never clear a newer registration.
   */
  registerTablist = modifier((element: HTMLElement) => {
    if (DEBUG) {
      assert(
        "d-tabs: a group renders one Tablist — the <:header> block must place it exactly once",
        this.#tablistActual === null ||
          this.#tablistActual === element ||
          !this.#tablistActual.isConnected
      );
    }

    this.#tablistActual = element;
    this.#deferTrackedWrite(() => {
      if (this.#tablistActual === element) {
        this.tablistElement = element;
      }
    });

    return () => {
      if (this.#tablistActual === element) {
        this.#tablistActual = null;
      }
      if (this.tablistElement === element) {
        this.tablistElement = null;
      }
    };
  });

  /**
   * The panel's swap effects, keyed on `@active`: reset the shared scroll
   * surface, and rescue focus when the outgoing content held it. Focus
   * whereabouts are tracked with listeners rather than read at swap time,
   * because by then the outgoing content is already gone.
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
        if (
          previousTarget instanceof Node &&
          previousTarget.isConnected &&
          !element.contains(document.activeElement)
        ) {
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
      // The destroy queue runs after afterRender and is where the outgoing
      // content detaches. Earlier, focus still looks held inside the panel.
      schedule("destroy", () => {
        if (isDestroying(this) || !element.isConnected) {
          return;
        }

        element.scrollTop = 0;

        // Focus on body is the removal signature; any real control means the
        // user moved on. Recomputing afterwards heals a stale flag.
        if (this.#focusWasInPanel && document.activeElement === document.body) {
          element.focus();
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
   * Opaque DOM-id suffixes per tab id. Consumer ids cannot go into DOM ids:
   * `aria-labelledby` splits on whitespace, so an id like "account settings"
   * would reference two missing elements.
   */
  #domIdSuffixes = new Map<string, number>();
  #nextDomIdSuffix = 0;

  /**
   * Untracked mirrors written synchronously at modifier install. The tracked
   * twins are written one hop later, because a tracked write from a modifier
   * lands inside the transaction that already read it.
   *
   * The DEBUG guards read these so they never race the deferral.
   */
  #tablistActual: HTMLElement | null = null;
  #panelActual: HTMLElement | null = null;

  /** Whether focus currently sits inside the tabpanel; survives re-renders. */
  #focusWasInPanel = false;

  /** The `@active` the panel effects last saw, to tell swaps from setup. */
  #lastSwapActive: unknown = NEVER_RENDERED;
  #strayScanQueued = false;
  #revealQueued = false;

  /** Same-id registrations awaiting the post-render duplicate verdict. */
  #pendingDuplicateChecks: Array<{
    id: string;
    first: Element;
    second: Element;
  }> = [];

  /** The stable state-and-controls bag the curried parts read live. */
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
      tabDomIdFor: (id: string) => this.#tabDomIdFor(id),
      activate: (id: string) => this.args.onActivate(id),
      activateFromElement: (item: HTMLElement) => {
        const id = item.dataset.dTab;
        if (id !== undefined) {
          this.args.onActivate(id);
        }
      },
      registerTab: this.registerTab,
      registerTablist: this.registerTablist,
      checkTabLabel: (
        id: string,
        label: string | undefined,
        hasBlock: boolean
      ) => {
        if (DEBUG) {
          assert(
            `d-tabs: tab "${id}" needs either @label or a <:label> block, and not both`,
            (label !== undefined) !== hasBlock
          );
        }
      },
    };
  })();
  @tracked _panelElement: HTMLElement | null = null;
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
   * The DOM id of the active tab's button, or `undefined` while `@active`
   * names no registered tab, so the panel's labelling can fall back rather
   * than reference a ghost.
   */
  get activeTabDomId() {
    void this._tabsVersion;
    const { active } = this.args;

    if (active === undefined || !this.#tabs.has(active)) {
      return undefined;
    }

    return this.#tabDomIdFor(active);
  }

  /** The widget-level name stands in while no tab labels the panel. */
  get panelAriaLabel() {
    if (this.hasTabs && this.activeTabDomId === undefined) {
      return this.args.label;
    }

    return undefined;
  }

  /**
   * The yielded parts, curried once. The engine bag reads no tracked state,
   * so the cache never invalidates and part identity survives every
   * re-render. That is what keeps a tab's label subtree alive across
   * activations.
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

  #tabDomIdFor(id: string) {
    let suffix = this.#domIdSuffixes.get(id);
    if (suffix === undefined) {
      suffix = this.#nextDomIdSuffix++;
      this.#domIdSuffixes.set(id, suffix);
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

  /**
   * Queues one post-render reveal of the selected tab. Registration and
   * selection both queue it, since either can put the selected button
   * outside the strip's scroll window.
   */
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
   * Scrolls the strip, and only the strip, until the selected tab sits
   * fully inside it. The page is never scrolled: a tab change is not a
   * reason to move the reader.
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
   * tab. Queued from tab registration rather than construction so it runs
   * after the declaration block has actually landed in the tablist.
   */
  #queueStrayContentScan() {
    if (this.#strayScanQueued) {
      return;
    }
    this.#strayScanQueued = true;

    schedule("afterRender", () => {
      this.#strayScanQueued = false;
      if (isDestroying(this) || !this.#tablistActual) {
        return;
      }

      // Duplicates first: a branch replacement's predecessor has detached
      // by now, while a genuine duplicate has both claimants attached.
      const pending = this.#pendingDuplicateChecks.splice(0);
      for (const { id, first, second } of pending) {
        assert(
          `d-tabs: duplicate tab id "${id}" — tab ids must be unique within a group`,
          !(first.isConnected && second.isConnected)
        );
      }

      for (const node of this.#tablistActual.childNodes) {
        // A role="tab" impostor that never registered is as stray as a div:
        // it would join the keyboard cursor without joining the group.
        const isStrayElement =
          node instanceof Element &&
          (node.getAttribute("role") !== "tab" ||
            this.#tabs.get(node.getAttribute("data-d-tab") ?? "") !== node);
        const isStrayText =
          node.nodeType === Node.TEXT_NODE &&
          (node.textContent ?? "").trim() !== "";

        assert(
          "d-tabs: the declaration block may contain only tab declarations — found unexpected content in the tablist",
          !isStrayElement && !isStrayText
        );
      }
    });
  }

  <template>
    <div class="d-tabs" ...attributes>
      {{#if (has-block "header")}}
        {{yield this.parts.headerBag to="header"}}
      {{else}}
        <div class="d-tabs__strip"><this.parts.headerBag.Tablist /></div>
      {{/if}}

      <div
        class="d-tabs__panel"
        id={{this.panelDomId}}
        role={{if this.hasTabs "tabpanel"}}
        tabindex={{if this.hasTabs "0"}}
        aria-labelledby={{this.activeTabDomId}}
        aria-label={{this.panelAriaLabel}}
        {{this.registerPanel}}
        {{this.panelEffects @active}}
      ></div>

      <DConditionalInElement @element={{this.tablistElement}}>
        {{yield this.parts.bag}}
      </DConditionalInElement>
    </div>
  </template>
}
