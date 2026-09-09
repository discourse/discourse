import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { warn } from "@ember/debug";
import {
  isDestroyed,
  isDestroying,
  registerDestructor,
} from "@ember/destroyable";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import Owner, { getOwner } from "@ember/owner";
import { next, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import curryComponent from "ember-curry-component";
import { modifier } from "ember-modifier";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import type { Side } from "discourse/lib/geometry";
import KeyValueStore from "discourse/lib/key-value-store";
import DConditionalInElement from "discourse/ui-kit/d-conditional-in-element";
import DResizeSeparator from "discourse/ui-kit/d-resize-separator";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { validContextKey } from "discourse/ui-kit/panel-dock/-internals/context-key";
import DockPicker from "discourse/ui-kit/panel-dock/-internals/parts/dock-picker";
import PanelDockInterior, {
  type PanelDockControls,
} from "discourse/ui-kit/panel-dock/-internals/parts/interior";
import {
  type DockSide,
  SIDES,
} from "discourse/ui-kit/panel-dock/-internals/sides";
import {
  type PanelWindowConnection,
  type PanelWindowGeometry,
  type PanelWindowHandle,
  type PanelWindowHost,
  type PanelWindowStrings,
  windowHostFor,
} from "discourse/ui-kit/panel-dock/-internals/window-host";
import { i18n } from "discourse-i18n";

/**
 * @returns The stored window rectangle when it is one a window could be opened
 * at, or `undefined` — a partly-measured or zero-sized one is worse than none.
 */
function restoreGeometry(stored: unknown): PanelWindowGeometry | undefined {
  if (typeof stored !== "object" || stored === null) {
    return undefined;
  }

  const { width, height, left, top } = stored as Record<string, unknown>;
  const numbers = [width, height, left, top];

  if (!numbers.every((value) => typeof value === "number" && isFinite(value))) {
    return undefined;
  }

  if ((width as number) <= 0 || (height as number) <= 0) {
    return undefined;
  }

  return {
    width: width as number,
    height: height as number,
    left: left as number,
    top: top as number,
  };
}

const STORE_NAMESPACE = "d_panel_dock_";
const DEFAULT_WIDTH = 320;
const MIN_WIDTH = 240;
const MAX_WIDTH = 720;
const DEFAULT_HEIGHT = 320;
const MIN_HEIGHT = 160;
const MAX_HEIGHT = 600;

/**
 * Where a panel is: against an edge of the page, or in a browser window of its
 * own. Orthogonal to which edge it is against, which it remembers either way.
 */
export type DockMode = DockLayout["mode"];

/** The panel's placement and sizes, as persisted between visits. */
interface DockLayout {
  mode: "docked" | "window";
  side: DockSide;
  width: number;
  height: number;
  window?: {
    width: number;
    height: number;
    left: number;
    top: number;
  };
}

interface PanelDockChassisSignature {
  /** The panel itself; the surrounding layer is not addressable. */
  Element: HTMLDivElement;
  Args: {
    /** Whether the panel is rendered. */
    isOpen?: boolean;

    /**
     * Name under which the panel's layout is remembered across visits.
     * Omitting it makes a resize or dock change last only as long as the panel
     * is rendered.
     *
     * Read once, when the panel is created: a panel that changed key mid-life
     * would write the layout it restored under the old one into the new one.
     */
    storageKey?: string;

    /**
     * Whether the header offers a dock side picker. Defaults to false. A
     * `main` block owns the interior instead, so it places the yielded
     * `DockPicker` itself and this argument no longer renders anything.
     */
    dockable?: boolean;

    /** The side used before the user picks one. Defaults to `"start"`. */
    defaultSide?: DockSide;

    /**
     * The width used before the user resizes, in pixels. Defaults to 320. A
     * stored width always wins over it.
     */
    defaultWidth?: number;

    /** Called with the chosen side when the user picks one. */
    onDock?: (side: DockSide) => void;

    /**
     * Called with the new size along the active axis, in pixels, once a
     * resize finishes.
     */
    onResize?: (size: number) => void;

    /**
     * Whether the panel may be moved into a browser window of its own.
     *
     * Off by default, because a panel that is part of the page it belongs to
     * has nothing to gain from it. Turning it on adds a choice to the dock
     * picker and lets a window left open by a previous visit be taken back.
     */
    windowable?: boolean;

    /** Called when the panel moves between an edge of the page and its own window. */
    onModeChange?: (mode: DockMode) => void;
  };
  Blocks: {
    /** The panel's header row. Omitting it leaves the panel headerless. */
    header: [];

    /**
     * Controls rendered at the end of the header row, after the dock picker,
     * so that a caller's close button stays last.
     */
    actions: [];

    /** The panel's content. */
    body: [];

    /**
     * The panel's whole interior, replacing the header row and the body.
     * For content that spans both — a tabs widget owning its strip row and
     * its panel as one tree — which the three-block split would cut in two.
     * The panel's own controls are yielded so they can be placed inside.
     */
    main: [controls: PanelDockControls];
  };
}

/**
 * A panel docked to an edge of the viewport that stays open while the page
 * behind it is used.
 *
 * It is deliberately not a modal: the page underneath keeps receiving clicks,
 * nothing is focus trapped, and scrolling is not locked. That is what makes it
 * suitable for content you consult *while* working, rather than content you
 * deal with and dismiss. For the latter, use `DModal`.
 *
 * The panel does not set a `z-index`. Where it belongs in the stacking order
 * depends on what it is being used for, so the caller styles that; the panel
 * only establishes the layer that lets clicks through.
 *
 * ```hbs
 * <PanelDockChassis @isOpen={{this.isOpen}} @storageKey="my-feature" @dockable={{true}}>
 *   <:header>Title</:header>
 *   <:actions><button type="button">Close</button></:actions>
 *   <:body>Content</:body>
 * </PanelDockChassis>
 * ```
 *
 * Content that cannot be cut along the header/body seam takes the `main`
 * block instead, which replaces both and yields the panel's own controls to
 * place.
 */
export default class PanelDockChassis extends Component<PanelDockChassisSignature> {
  /**
   * How the panel says what happened.
   *
   * `aria-busy` on the button marks it as updating; it does not announce, so
   * every transition a reader cannot see is spoken here instead.
   */
  @service
  declare a11y: {
    announce: (message: string, level?: string, delay?: number) => void;
  };

  /**
   * The injected value is the dynamic, per-request settings object built by the
   * `site-settings` service factory, not an instance of that module's class shim.
   */
  @service declare siteSettings: Record<string, unknown>;

  /**
   * The docked branch's own lifetime.
   *
   * It retries a held adoption, and it is also the only thing still rendered
   * while a window is on its way — so it is what notices a panel closing out
   * from under one, which never reaches the redocking path because the panel
   * is already docked.
   */
  openedGuard = modifier((_element, [windowable]: [boolean | undefined]) => {
    if (this.#adoptionPending && windowable) {
      // A full turn, not a render pass: at render time a panel that is being
      // taken apart still looks live, and acquiring a window for it would leave
      // one leased with nothing left to release it.
      next(() => {
        if (!this.#isReleasing) {
          this.#adoptStoredWindow();
        }
      });
    }

    return () => {
      // Deferred and re-read, because at cleanup time a panel that merely
      // moved into its window looks exactly like one that closed, and a panel
      // that closed and reopened inside a turn is still waiting legitimately.
      next(() => {
        if (this.#isReleasing || !this._connecting) {
          return;
        }

        if (!this.args.isOpen || !this.args.windowable) {
          this.#cancelConnection();
        }
      });
    };
  });

  /**
   * The window branch's own lifetime.
   *
   * Deliberately takes no arguments and is never rebuilt: an `ember-modifier`
   * update tears down synchronously before reinstalling, which would read as
   * the panel having left the window.
   */
  windowLifetime = modifier((element: HTMLElement) => {
    const generation = this.#generation;
    const mount = ++this.#branchMounts;
    this.#commitWindow(generation);

    if (this.#focusOnArrival) {
      this.#focusOnArrival = false;

      // After the render barrier, so the tree the reader is being sent to is
      // there when they arrive in it.
      schedule("afterRender", () => {
        if (this.#generation === generation && !this.#isReleasing) {
          element.focus();
        }
      });
    }

    return () => {
      if (this.#generation !== generation) {
        return;
      }

      // The branch went away with the panel still live, which only happens
      // when the panel was closed. Bring it back so the window is not orphaned.
      // Deferred a full turn, and re-checked when it runs, because at cleanup
      // time a panel that is being taken apart still looks like a live one.
      next(() => {
        // The generation again, and not only the mount count: by the time this
        // runs the panel may have returned and asked for a *second* window,
        // which has mounted no branch of its own yet — so the count still
        // matches while the placement it was captured for is long gone.
        if (this.#generation !== generation) {
          return;
        }

        // A panel that closed and opened again inside one turn is already back
        // in its window, and returning it now would close a live one.
        if (!this.#isReleasing && this.#branchMounts === mount) {
          this.#redock();
        }
      });
    };
  });

  /**
   * Watches for the panel losing permission to be in a window, which the
   * rendering condition cannot notice because it follows the mode alone.
   */
  windowableGuard = modifier(
    (_element, [windowable]: [boolean | undefined]) => {
      if (!windowable && this.isWindowed) {
        // Re-checked when it runs: permission may have come back in the
        // meantime, and returning the panel then would close a window it is
        // entitled to.
        schedule("afterRender", () => {
          if (!this.args.windowable && !this.#isReleasing) {
            this.#redock();
          }
        });
      }
    }
  );
  #store = new KeyValueStore(STORE_NAMESPACE);
  #host: PanelWindowHost;
  #windowGeometry: PanelWindowGeometry | null = null;

  /**
   * Bumped on every move between placements, so that work armed under an
   * earlier one — a window's own events, a scheduled callback, the readiness
   * acknowledgement — can tell that it has been overtaken.
   */
  #generation = 0;

  /**
   * Whether the panel has entered window mode but not yet proved it: nothing is
   * stored and nobody is told until the window has really rendered, so a window
   * that never appears leaves no trace of having been asked for.
   */
  #awaitingWindow = false;
  /** The placement the consumer has been told about. */
  #reportedMode: DockMode = "docked";

  /**
   * Whether a stored window is still waiting to be taken back. A panel that is
   * closed cannot render into a window, so it holds the attempt until it opens.
   */
  #adoptionPending = false;

  /** Whether the next window this panel enters was asked for just now. */
  #focusOnArrival = false;

  /**
   * Whether the panel itself is going away, as opposed to merely closing.
   *
   * Tracked here rather than asked of the framework at the moment it matters:
   * a modifier's cleanup can run before the component is marked, so the two
   * cases are told apart by this flag instead of by destruction bookkeeping
   * that is not yet true.
   */
  #releasing = false;

  /**
   * How many times the window branch has been mounted, so that work deferred
   * by one mount can tell that another has since taken over.
   */
  #branchMounts = 0;

  /**
   * The name the panel's layout is stored under, captured with the layout it
   * belongs to: reading it live would let a panel whose key changed write the
   * layout it restored under the old name into the new one.
   */
  #storageKey?: string;

  /**
   * The key the window is leased under, which outlives an unnamed panel.
   *
   * `null` when the panel's context cannot also be a URL segment, which is the
   * only thing that withholds window mode from an otherwise eligible panel.
   */
  #windowKey: string | null = null;
  @tracked _side: DockSide;
  @tracked _width: number;
  @tracked _height: number;

  /** Where the panel is. The only thing the template branches on. */
  @tracked _mode: DockMode = "docked";

  /**
   * The window the panel is in, when it is in one.
   *
   * Tracked rather than `#private` because the mount the panel renders into is
   * derived from it, and `@tracked` cannot decorate a private field.
   */
  @tracked _handle: PanelWindowHandle | null = null;

  /**
   * The window this panel asked for and has not been given yet.
   *
   * Not a mode: the panel stays docked and unchanged for the whole wait, and
   * stores and reports nothing. A window that never arrives has to cost the
   * reader nothing.
   */
  @tracked _connecting: PanelWindowConnection | null = null;

  constructor(owner: Owner, args: PanelDockChassisSignature["Args"]) {
    super(owner, args);

    this.#storageKey = args.storageKey;
    // Validated for the window only. A context that cannot be a URL segment
    // still stores its docked layout under itself, exactly as before: dropping
    // a remembered layout because an unrelated rule tightened would be worse
    // than the mismatch the rule prevents.
    this.#windowKey = validContextKey(this.#storageKey ?? guidFor(this));

    // Read once at construction rather than in getters. The stored layout is
    // only a starting point, and re-reading it on every render would undo a
    // resize that has not been committed yet.
    const layout = this.#restoreLayout();
    this._side = layout.side;
    this._width = layout.width;
    this._height = layout.height;
    this.#windowGeometry = layout.window ?? null;
    this.#host = windowHostFor(owner);
    this.#adoptionPending = layout.mode === "window";

    // Before the first render rather than after it, so a panel that belongs in
    // a window never appears against an edge on the way there.
    this.#adoptStoredWindow();

    registerDestructor(this, () => {
      this.#releasing = true;
      this.#cancelConnection();
      this._handle?.dispose();
    });
  }

  get side() {
    return this._side;
  }

  /** Whether the panel is in a window of its own rather than against an edge. */
  get isWindowed() {
    return this._mode === "window";
  }

  /** Where the panel's tree renders while it is in a window. */
  get popupMount() {
    return this._handle?.mount ?? null;
  }

  /** The window's title, which is also the panel's accessible name in it. */
  get windowTitle() {
    return i18n("panel_dock.window_title", {
      site_title: String(this.siteSettings?.title ?? ""),
    });
  }

  get isBottom() {
    return this._side === "bottom";
  }

  /**
   * The current width, clamped to the range the panel can be dragged to.
   *
   * @returns A width in pixels.
   */
  get width() {
    return Math.min(Math.max(this._width, MIN_WIDTH), this.maxWidth);
  }

  /**
   * The largest width the panel may take, given the space available.
   *
   * The viewport term lives here rather than in the stylesheet so that the
   * width reported through `aria-valuenow` and `@onResize` is the width that
   * actually renders. A `90vw` cap applied only in CSS would silently diverge
   * from both on a narrow viewport.
   *
   * @returns A width in pixels.
   */
  get maxWidth() {
    if (this.isWindowed) {
      return MAX_WIDTH;
    }

    return Math.min(MAX_WIDTH, Math.round(window.innerWidth * 0.9));
  }

  /** The current height, clamped like the width. */
  get height() {
    return Math.min(Math.max(this._height, MIN_HEIGHT), this.maxHeight);
  }

  get maxHeight() {
    if (this.isWindowed) {
      return MAX_HEIGHT;
    }

    return Math.min(MAX_HEIGHT, Math.round(window.innerHeight * 0.8));
  }

  /** The size along the axis the active dock side resizes on. */
  get size() {
    return this.isBottom ? this.height : this.width;
  }

  get minSize() {
    return this.isBottom ? MIN_HEIGHT : MIN_WIDTH;
  }

  get maxSize() {
    return this.isBottom ? this.maxHeight : this.maxWidth;
  }

  /**
   * The separator's `@side` — the anchored edge along the active axis, which
   * is the dock side itself. It collapses to two values because a bottom dock
   * anchors at its block-end edge, so only a start dock resolves to `"start"`.
   */
  get anchoredSide(): Side {
    return this._side === "start" ? "start" : "end";
  }

  /**
   * The sizes, as custom properties for the stylesheet to consume.
   *
   * Custom properties rather than inline dimensions keep the sizing rules in
   * the stylesheet, where the dock side modifier decides which one applies.
   *
   * @returns A style attribute value.
   */
  get style() {
    return trustHTML(
      `--d-panel-dock-width: ${this.width}px; --d-panel-dock-height: ${this.height}px;`
    );
  }

  /**
   * The dock picker, pre-wired to this panel, for a `main` block to place.
   *
   * Curried rather than yielded raw so the caller cannot cross-wire it to
   * another panel's side, and so placing it stays a single empty tag.
   */
  @cached
  get dockPicker() {
    return curryComponent(
      DockPicker,
      {
        isSide: this.isSide,
        onSelect: this.setSide,
        isWindowed: this.isWindowedNow,
        isConnecting: this.isConnectingNow,
        // Reading the argument here is what rebuilds the picker when a panel
        // becomes windowable; the two above stay stable so the pressed state
        // re-renders without the picker being replaced.
        onSelectWindow:
          this.args.windowable && this.#windowKey ? this.undock : undefined,
      },
      getOwner(this)!
    );
  }

  /**
   * Updates the rendered size along the active axis without storing it.
   *
   * @param size - The size to render, in pixels.
   */
  @action
  previewSize(size: number) {
    if (this.isBottom) {
      this._height = size;
    } else {
      this._width = size;
    }
  }

  /**
   * Stores the size the panel was left at.
   *
   * @param size - The size to store, in pixels.
   */
  @action
  commitSize(size: number) {
    this.previewSize(size);
    this.#persist();
    this.args.onResize?.(size);
  }

  /**
   * Docks the panel against the given side.
   *
   * @param side - The side to dock against.
   */
  @action
  setSide(side: DockSide) {
    this.#redock();
    this._side = side;
    this.#persist();
    this.args.onDock?.(side);
  }

  @action
  isSide(side: DockSide) {
    return this._mode === "docked" && this._side === side;
  }

  /**
   * Read through an action so the curried argument set stays stable: rebuilding
   * the picker on every change would replace the button the reader is on.
   */
  @action
  isConnectingNow() {
    return this._connecting !== null;
  }

  @action
  isWindowedNow() {
    return this.isWindowed;
  }

  /**
   * Moves the panel into a window of its own.
   *
   * Must run straight from the gesture that asked for it: a browser refuses a
   * window opened any later. Nothing is stored or reported here — that waits
   * until the window has actually rendered.
   */
  @action
  undock() {
    if (this.isWindowed) {
      this._handle?.focus();
      return;
    }

    // The lease would refuse a second request anyway, but warning at a reader
    // for pressing twice is noise. Raise what they already asked for.
    if (this._connecting) {
      this._connecting.focus();
      return;
    }

    if (!this.#windowKey) {
      return;
    }

    const outcome = this.#host.open(
      this.#windowKey,
      this.#windowStrings,
      this.#windowGeometry
    );

    if (outcome.status === "unavailable") {
      warn("The panel's window was refused, so it stays docked.", false, {
        id: "discourse.panel-dock.popup-blocked",
      });
      return;
    }

    if (outcome.status === "already-leased") {
      warn(
        "Another panel already holds this window, so it stays docked.",
        false,
        {
          id: "discourse.panel-dock.duplicate-context",
        }
      );
      return;
    }

    if (outcome.status === "acquired") {
      this.#takeWindow(outcome.handle);
      return;
    }

    this.a11y.announce(i18n("panel_dock.window_connecting"), "polite");
    this.#focusOnArrival = true;
    this.#beginWindow(outcome.connection);
  }

  /**
   * Brings the panel back to the edge it came from.
   *
   * The window is measured before anything else, because a window that has
   * begun closing reports nothing worth keeping.
   */
  #redock() {
    this.#cancelConnection();

    if (!this.isWindowed) {
      return;
    }

    const handle = this._handle;
    const measured = handle?.measure();
    if (measured) {
      this.#windowGeometry = measured;
    }

    // A window mode that never proved itself is rolled back in silence: the
    // consumer was never told it happened and storage never recorded it.
    const wasCommitted = !this.#awaitingWindow;
    this.#enter("docked", null);

    // After the render barrier, so the tree has left the window before the
    // window does.
    schedule("afterRender", () => handle?.dispose());

    if (wasCommitted) {
      this.#persist();
      this.#report("docked");
    }

    this.#focusOnArrival = false;
  }

  /** What the window shows: its title, and the note left when this page goes. */
  get #windowStrings(): PanelWindowStrings {
    return {
      title: this.windowTitle,
      note: {
        title: i18n("panel_dock.window_reconnecting_title"),
        body: i18n("panel_dock.window_reconnecting_body"),
      },
    };
  }

  /**
   * Takes back the window a previous visit left open.
   *
   * A panel that cannot render cannot adopt, so a closed one keeps the attempt
   * until it opens. Only a definite absence rewrites the stored mode: a window
   * held by another panel is that panel's to record, not this one's.
   */
  #adoptStoredWindow() {
    if (
      !this.#adoptionPending ||
      !this.#windowKey ||
      !this.args.windowable ||
      !this.args.isOpen
    ) {
      return;
    }

    this.#adoptionPending = false;
    const outcome = this.#host.adopt(this.#windowKey, this.#windowStrings);

    if (outcome.status === "acquired") {
      this.#takeWindow(outcome.handle);
      return;
    }

    if (outcome.status === "unavailable") {
      this.#persist();
    }
  }

  /**
   * Enters window mode and starts waiting for the branch to prove it.
   *
   * The wait is bounded: a branch that never renders — because it threw, or
   * because there was nothing to render into — would otherwise leave the
   * window leased with no panel in it and nothing to release it.
   */
  /**
   * Waits for a window without moving into it.
   *
   * The panel stays where it is for the whole wait: nothing is stored, nothing
   * is reported, and no branch is torn down. Only an arrival moves it.
   */
  #beginWindow(connection: PanelWindowConnection) {
    this._connecting = connection;

    // Captured rather than bumped. Everything that gives the attempt up bumps
    // the generation, so a settlement that arrives afterwards recognizes itself
    // as stale without having to know which of them ran.
    const generation = this.#generation;

    connection.onReady((handle) => {
      if (this.#generation !== generation) {
        return;
      }

      this._connecting = null;

      // Re-read here rather than trusted from when the window was asked for:
      // an argument can change without the generation moving, so the panel may
      // have closed or lost permission while the window was still coming.
      if (!this.#mayWindow) {
        handle.dispose();
        return;
      }

      this.a11y.announce(i18n("panel_dock.window_opened"), "polite");
      this.#takeWindow(handle);
    });

    connection.onFailed(() => {
      if (this.#generation !== generation) {
        return;
      }

      this._connecting = null;

      if (this.#isReleasing) {
        return;
      }

      // Assertive, because the reader asked for something and it did not
      // happen; a polite queue would tell them long after they moved on.
      this.a11y.announce(i18n("panel_dock.window_refused"), "assertive");
      warn("The panel's window never arrived, so it stays docked.", false, {
        id: "discourse.panel-dock.window-unavailable",
      });
    });
  }

  /** Whether a window would still be the right place for this panel to be. */
  get #mayWindow() {
    return !this.#isReleasing && !!this.args.isOpen && !!this.args.windowable;
  }

  /** Gives up a window that has not arrived, closing it if it since has. */
  #cancelConnection() {
    const connection = this._connecting;

    if (!connection) {
      return;
    }

    // Bumped before cancelling, because cancelling settles the connection
    // synchronously and the handlers armed above have to read as stale by the
    // time they run.
    this.#generation++;

    if (!this.#isReleasing) {
      this._connecting = null;
    }

    connection.cancel();
  }

  #takeWindow(handle: PanelWindowHandle) {
    this.#enter("window", handle);
    this.#awaitingWindow = true;
    this.#arm(handle);

    // Outside the render queue, so it still fires if the render itself threw.
    const generation = this.#generation;
    next(() => {
      if (
        this.#generation === generation &&
        this.#awaitingWindow &&
        !this.#isReleasing
      ) {
        this.#redock();
      }
    });
  }

  /** Subscribes to the window's own life, under the current generation. */
  #arm(handle: PanelWindowHandle) {
    const generation = this.#generation;

    handle.onPagehide(() => {
      if (this.#generation === generation && !this.#isReleasing) {
        this.#redock();
      }
    });

    handle.onResize(() => {
      if (this.#generation !== generation || this.#awaitingWindow) {
        return;
      }

      const measured = handle.measure();
      if (measured) {
        this.#windowGeometry = measured;
        this.#persist();
      }
    });
  }

  /** Whether the panel is being taken apart rather than merely closed. */
  get #isReleasing() {
    return this.#releasing || isDestroying(this) || isDestroyed(this);
  }

  /** Records that the panel really is where it says it is. */
  #commitWindow(generation: number) {
    if (this.#generation !== generation || !this.#awaitingWindow) {
      return;
    }

    this.#awaitingWindow = false;
    this._handle?.clearNote();

    // From here the stored placement says "window", so a later page has
    // something telling it to come looking and the window may be handed on
    // rather than closed when this one unloads.
    this._handle?.commit();
    this.#persist();
    this.#report("window");
  }

  /** Moves the panel, without recording or reporting anything. */
  #enter(mode: DockMode, handle: PanelWindowHandle | null) {
    this.#generation++;
    this.#awaitingWindow = false;
    this._mode = mode;
    this._handle = handle;
  }

  /** Tells the consumer, at most once per placement. */
  #report(mode: DockMode) {
    // A callback fired at a consumer that is going away is not a placement
    // change; it is a stray call into something that has stopped listening.
    if (this.#reportedMode === mode || this.#isReleasing) {
      return;
    }

    this.#reportedMode = mode;
    this.args.onModeChange?.(mode);
  }

  #persist() {
    if (!this.#storageKey) {
      return;
    }

    this.#store.setObject({
      key: this.#storageKey,
      value: {
        mode: this._mode,
        side: this.side,
        width: this.width,
        height: this.height,
        ...(this.#windowGeometry ? { window: this.#windowGeometry } : {}),
      } satisfies DockLayout,
    });
  }

  /**
   * Reads the layout this panel was last left at.
   *
   * Anything stored that is not a recognizable layout object is ignored and
   * the defaults apply.
   *
   * @returns The stored layout, or the defaults when there is none.
   */
  #restoreLayout(): DockLayout {
    const fallback: DockLayout = {
      mode: "docked",
      side: this.args.defaultSide ?? "start",
      width: this.args.defaultWidth ?? DEFAULT_WIDTH,
      height: DEFAULT_HEIGHT,
    };

    if (!this.#storageKey) {
      return fallback;
    }

    const stored = this.#store.getObject(this.#storageKey) as
      | {
          side?: unknown;
          width?: unknown;
          height?: unknown;
          mode?: unknown;
          window?: unknown;
        }
      | number
      | undefined;

    if (
      typeof stored === "object" &&
      stored !== null &&
      SIDES.includes(stored.side as DockSide) &&
      typeof stored.width === "number" &&
      typeof stored.height === "number"
    ) {
      return {
        mode: stored.mode === "window" ? "window" : "docked",
        side: stored.side as DockSide,
        width: stored.width,
        height: stored.height,
        ...(restoreGeometry(stored.window)
          ? { window: restoreGeometry(stored.window)! }
          : {}),
      };
    }

    return fallback;
  }

  <template>
    {{#if @isOpen}}
      {{#if this.isWindowed}}
        <DConditionalInElement @element={{this.popupMount}}>
          <div
            class={{dConcatClass "d-panel-dock" "--window"}}
            role="region"
            aria-label={{this.windowTitle}}
            tabindex="-1"
            ...attributes
            {{this.windowLifetime}}
            {{this.windowableGuard @windowable}}
          >
            <PanelDockInterior
              @dockable={{@dockable}}
              @dockPicker={{this.dockPicker}}
              @hasActions={{has-block "actions"}}
              @hasHeader={{has-block "header"}}
              @hasMain={{has-block "main"}}
            >
              <:header>{{yield to="header"}}</:header>
              <:actions>{{yield to="actions"}}</:actions>
              <:body>{{yield to="body"}}</:body>
              <:main as |controls|>{{yield controls to="main"}}</:main>
            </PanelDockInterior>
          </div>

          {{! A live region is only read in the document that has focus, so the
              page's own regions are inaudible from here. Same service, second
              mount. }}
          <A11yLiveRegions />
        </DConditionalInElement>
      {{else}}
        {{! The layer spans the viewport so the panel can be positioned against
            its edges, but lets pointer events through so the page underneath
            stays usable. The panel itself takes them back. }}
        <div class="d-panel-dock-layer">
          <div
            class={{dConcatClass "d-panel-dock" (concat "--dock-" this.side)}}
            style={{this.style}}
            ...attributes
            {{this.openedGuard @windowable}}
          >
            <PanelDockInterior
              @dockable={{@dockable}}
              @dockPicker={{this.dockPicker}}
              @hasActions={{has-block "actions"}}
              @hasHeader={{has-block "header"}}
              @hasMain={{has-block "main"}}
            >
              <:header>{{yield to="header"}}</:header>
              <:actions>{{yield to="actions"}}</:actions>
              <:body>{{yield to="body"}}</:body>
              <:main as |controls|>{{yield controls to="main"}}</:main>
            </PanelDockInterior>

            <DResizeSeparator
              class="d-panel-dock__resizer"
              @axis={{if this.isBottom "vertical" "horizontal"}}
              @side={{this.anchoredSide}}
              @value={{this.size}}
              @min={{this.minSize}}
              @max={{this.maxSize}}
              @label={{i18n "panel_dock.resize"}}
              @onResize={{this.previewSize}}
              @onResizeEnd={{this.commitSize}}
            />
          </div>
        </div>
      {{/if}}
    {{/if}}
  </template>
}
