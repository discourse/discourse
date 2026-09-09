/**
 * The seam between a panel and the separate browser window it can move into.
 *
 * A window is leased, not owned: the page that opened it holds exactly one
 * lease per storage key, so two panels sharing a key can never both drive the
 * same window, and a page that comes back after a reload can recognize the
 * window it left behind and take it over rather than opening a second one.
 *
 * The lease also outlives the page in one direction only. When the page goes
 * away for good a window the reader can still see stays open showing a note,
 * because closing it would destroy work in front of them; when the page is
 * merely suspended the window keeps its whole rendered tree and is resumed in
 * place. A window the *storage* does not know about yet is the exception, and
 * is closed: nothing records it, so no later page would ever come for it.
 *
 * Opening is asynchronous and adopting is not. The window is a page the server
 * renders, so a new one arrives over the network, while re-opening an existing
 * one by name hands back the same window without navigating it — which is what
 * lets a panel that belongs in a window be taken back into it before the first
 * render, with no flash against an edge on the way.
 */

import type Owner from "@ember/owner";
import getURL from "discourse/lib/get-url";
import {
  mirrorOpener,
  type OpenerMirror,
} from "discourse/ui-kit/panel-dock/-internals/opener-mirror";
import {
  adoptShell,
  type PanelWindowShell,
  shellKey,
} from "discourse/ui-kit/panel-dock/-internals/window-shell";

/** The registration a host is looked up under, so a test can supply its own. */
export const WINDOW_HOST_REGISTRATION = "panel-dock:window-host";

/** Where a panel window sat, as measured from the window itself. */
export interface PanelWindowGeometry {
  /** The window's outer width in pixels. */
  width: number;

  /** The window's outer height in pixels. */
  height: number;

  /** The window's distance from the left of the screen, in pixels. */
  left: number;

  /** The window's distance from the top of the screen, in pixels. */
  top: number;
}

/** What a window's note says, kept apart from the markup the server rendered. */
export interface PanelWindowNote {
  /** The heading, which the server has already rendered into the shell. */
  title: string;

  /**
   * The body, written into the shell's live region at the moment it is shown.
   *
   * Not served populated: a live region that already holds its text and is
   * merely unhidden is not a content change, and does not announce.
   */
  body: string;
}

/** The text a window needs, resolved once per lease so later writes are pure DOM. */
export interface PanelWindowStrings {
  /** The window's title. */
  title: string;

  /** What the window shows once the page that owns it is gone. */
  note: PanelWindowNote;
}

/**
 * One leased panel window.
 *
 * Every asynchronous callback a caller registers is tagged with the
 * {@link PanelWindowHandle.generation} it was armed under, so a callback that
 * arrives after the lease moved on can be recognized as stale rather than
 * acted on.
 */
export interface PanelWindowHandle {
  /** The element the panel's tree renders into. */
  readonly mount: HTMLElement;

  /** The lease this handle belongs to. Never reused. */
  readonly generation: number;

  /** Whether the window has gone away. */
  readonly closed: boolean;

  /**
   * Whether the page that owns this window is unloading for good.
   *
   * A suspended handle keeps its window open and its note showing: the
   * teardown that follows a reload must not close the window the next page is
   * about to adopt.
   */
  readonly suspended: boolean;

  /** Brings the window to the front. */
  focus(): void;

  /** Closes the window, unless it is suspended. */
  close(): void;

  /**
   * @returns Where the window sits now, or `null` when it cannot be measured —
   * a closing window reports zeros, which would overwrite a good position.
   */
  measure(): PanelWindowGeometry | null;

  /** Shows the note in place of the panel. */
  showNote(): void;

  /** Puts the panel back. */
  clearNote(): void;

  /** Called when the window itself is navigated away or closed by the reader. */
  onPagehide(callback: () => void): void;

  /** Called, throttled, while the reader resizes or moves the window. */
  onResize(callback: () => void): void;

  /**
   * Releases everything this handle owns and ends the lease.
   *
   * On a suspended handle this detaches the page's own work and leaves the
   * window standing. Safe to call more than once.
   */
  dispose(): void;

  /**
   * Records that the panel really is in this window and something says so.
   *
   * Until this is called nothing outside the page knows the window exists, so
   * a page that unloads before it must close the window rather than hand it
   * on: no later page would have anything telling it to come looking.
   */
  commit(): void;
}

/**
 * A window that has been asked for and has not arrived.
 *
 * Deliberately not a {@link PanelWindowHandle}: holding a handle means holding
 * a live mount, and this has none yet. It does hold the key, from the moment
 * it is asked for, so two presses cannot race for one window.
 */
export interface PanelWindowConnection {
  /** The generation the eventual handle will carry, reserved at lease time. */
  readonly generation: number;

  /** Raises the window on its way, for a reader who asked a second time. */
  focus(): void;

  /** Fires once, when the window has loaded a shell this panel may take. */
  onReady(callback: (handle: PanelWindowHandle) => void): void;

  /**
   * Fires once, when the window is given up on.
   *
   * The lease is already released and the window already closed by the time
   * this runs, so a caller may ask for another window from inside it.
   */
  onFailed(callback: (reason: PanelWindowFailure) => void): void;

  /** Gives up: stops probing, closes the window, releases the key. */
  cancel(): void;
}

/** Why a window that was asked for never became one the panel could use. */
export type PanelWindowFailure =
  /** It went away before it arrived. */
  | "closed"
  /** It never finished arriving within the budget it was given. */
  | "timeout"
  /** It finished arriving as something that is not this panel's shell. */
  | "foreign";

/**
 * What came of asking for a window.
 *
 * The cases are deliberately distinct rather than a nullable handle, because
 * only `unavailable` means "there is no window to be had" and may rewrite a
 * stored layout. `already-leased` means another panel holds this key and the
 * caller must change nothing.
 */
export type PanelWindowOutcome =
  | { status: "acquired"; handle: PanelWindowHandle }
  | { status: "connecting"; connection: PanelWindowConnection }
  | { status: "already-leased" }
  | { status: "unavailable" };

/**
 * What a window is being resolved for.
 *
 * Only one of the two carries a URL, because naming an existing window with
 * one navigates it — destroying the very tree adoption exists to take over.
 * Making that a type rather than a rule is the point.
 */
export type WindowResolution =
  | { intent: "open"; url: string; geometry?: PanelWindowGeometry | null }
  | { intent: "adopt" };

/** Supplies panel windows and holds the leases on them. */
export interface PanelWindowHost {
  /**
   * Opens a new window. Must be called synchronously from the gesture that
   * asked for it, or the browser will refuse it.
   *
   * The key is held from here, but the window is a page that has to arrive, so
   * this answers `connecting` and the caller waits. Only a refused popup is
   * still answerable in the same breath.
   *
   * @param geometry - Where to put it, when a previous session measured it.
   */
  open(
    key: string,
    strings: PanelWindowStrings,
    geometry?: PanelWindowGeometry | null
  ): PanelWindowOutcome;

  /**
   * Takes over the window a previous visit left open, if it is still there and
   * still recognizably this panel's.
   */
  adopt(key: string, strings: PanelWindowStrings): PanelWindowOutcome;
}

/**
 * The window each storage key is currently held by.
 *
 * Module-wide rather than per host, because window names are global to the
 * browser: two hosts asking for the same key are asking for the same window,
 * and the lease has to be at least as wide as the thing it guards.
 */
const leases = new Map<string, Lease>();

let lastGeneration = 0;

/**
 * Releases every lease this page holds.
 *
 * The registry is module-wide and outlives an application, so a test that left
 * a window leased would strand that key for every test after it. Production has
 * no reason to call this: a page that is going away takes its leases with it.
 */
export function releaseAllPanelWindows(): void {
  for (const held of [...leases.values()]) {
    held.dispose();
  }

  leases.clear();
}

/**
 * What a key can be held by.
 *
 * A window still loading holds its key exactly as firmly as one that arrived,
 * or a second press would open a rival window onto the same name.
 */
interface Lease {
  readonly closed: boolean;
  dispose(): void;
}

/**
 * The lease currently holding a key, if one still has anything to hold.
 *
 * A window the reader closed leaves its lease behind until the panel notices,
 * and treating that as live would strand the key for the rest of the page's
 * life. Reaping it here means asking for a window is always answerable.
 */
function heldLease(key: string): Lease | undefined {
  const held = leases.get(key);

  if (!held) {
    return undefined;
  }

  if (held.closed) {
    held.dispose();
    return undefined;
  }

  return held;
}

/** How a leased window reports back to the host holding it. */
interface LeaseHolder {
  /** Called once the handle has let go of its window. */
  released(handle: PanelWindow): void;

  /** Called once a connection has settled, either way. */
  settled(connection: PendingWindow): void;
}

/**
 * One leased window.
 *
 * Not exported: a caller only ever meets it as a {@link PanelWindowHandle},
 * and the extra members here are how the host drives it through the opening
 * page's own lifecycle.
 */
class PanelWindow implements PanelWindowHandle {
  readonly generation: number;
  readonly mount: HTMLElement;

  #committed = false;
  #holder: LeaseHolder;
  #key: string;
  #mirror: OpenerMirror;
  #pagehideCallbacks: (() => void)[] = [];
  #paused = false;
  #released = false;
  #resizeCallbacks: (() => void)[] = [];
  #resizeFrame?: number;
  #resizeGeneration = 0;
  #shell: PanelWindowShell;
  #strings: PanelWindowStrings;
  #suspended = false;
  #window: Window;

  #onWindowPagehide = (): void => {
    this.#pagehideCallbacks.forEach((callback) => callback());
  };

  /**
   * Dragging a window edge fires a burst of these, and acting on each one would
   * measure and persist dozens of times per drag.
   *
   * Scheduled on the panel window's own frames rather than the opening page's:
   * the page can be a background tab whose frames are throttled while the
   * window the reader is dragging is perfectly visible.
   */
  #onWindowResize = (): void => {
    if (this.#resizeFrame !== undefined) {
      return;
    }

    // Cancelling a frame is something a window we have lost is allowed to
    // refuse, so what a frame was armed under is the guarantee and cancelling
    // it is only the optimisation.
    const generation = this.#resizeGeneration;

    try {
      this.#resizeFrame = this.#window.requestAnimationFrame(() => {
        if (generation !== this.#resizeGeneration) {
          return;
        }

        this.#resizeFrame = undefined;
        this.#resizeCallbacks.forEach((callback) => callback());
      });
    } catch {
      // A window that went away mid-drag has nothing left to measure.
    }
  };

  constructor(options: {
    generation?: number;
    holder: LeaseHolder;
    key: string;
    mirror: OpenerMirror;
    shell: PanelWindowShell;
    strings: PanelWindowStrings;
    window: Window;
  }) {
    // Reserved when the window was asked for, when there is a connection to
    // inherit it from: one lease is one generation, whether it arrived at once
    // or over the network.
    this.generation = options.generation ?? ++lastGeneration;
    this.#holder = options.holder;
    this.#key = options.key;
    this.#mirror = options.mirror;
    this.#shell = options.shell;
    this.#strings = options.strings;
    this.#window = options.window;
    this.mount = options.shell.mount;

    // Listening starts here rather than when the window was asked for, because
    // a handle only exists once the window has finished arriving. A navigation
    // replaces the window's global, so anything registered on the one that was
    // there beforehand is gone by now.
    this.#listen();
  }

  commit(): void {
    this.#committed = true;
  }

  get closed(): boolean {
    try {
      return this.#window.closed;
    } catch {
      return true;
    }
  }

  get suspended(): boolean {
    return this.#suspended;
  }

  clearNote(): void {
    if (this.#suspended) {
      return;
    }

    this.#shell.setNote(null);
  }

  close(): void {
    if (this.#suspended || this.#released || this.closed) {
      return;
    }

    this.#closeWindow();
  }

  dispose(): void {
    if (this.#released) {
      return;
    }

    this.#released = true;

    // Everything below this point is bookkeeping the page depends on, so a
    // window that has navigated somewhere we cannot reach must not be able to
    // abandon it half done by throwing.
    try {
      this.#ignore();
      this.#shell.dispose();
      this.#mirror.dispose();
    } catch {
      // Nothing reachable to clean up.
    }

    // Only while this handle is still the one on record: a handle whose lease
    // was already taken over must not release its successor's.
    if (leases.get(this.#key) === this) {
      leases.delete(this.#key);
    }

    if (!this.#suspended && !this.closed) {
      this.#closeWindow();
    }

    this.#pagehideCallbacks = [];
    this.#resizeCallbacks = [];
    this.#holder.released(this);
  }

  focus(): void {
    if (this.#suspended || this.#released || this.closed) {
      return;
    }

    try {
      this.#window.focus();
    } catch {
      // A window that went away between the check and the call is not an error.
    }
  }

  measure(): PanelWindowGeometry | null {
    try {
      const { outerWidth: width, outerHeight: height } = this.#window;

      // A closing window reports zeros, and storing those would move the next
      // window to a corner it was never opened at.
      if (!(width > 0) || !(height > 0)) {
        return null;
      }

      return {
        width,
        height,
        left: this.#window.screenX,
        top: this.#window.screenY,
      };
    } catch {
      return null;
    }
  }

  onPagehide(callback: () => void): void {
    this.#pagehideCallbacks.push(callback);
  }

  onResize(callback: () => void): void {
    this.#resizeCallbacks.push(callback);
  }

  /** Stops reporting to a page that is suspended, without giving anything up. */
  pause(): void {
    if (this.#paused) {
      return;
    }

    this.#paused = true;
    this.#ignore();
    this.#shell.setNote(this.#strings.note.body);
  }

  /** Reports again to a page that came back, under the same lease. */
  resume(): void {
    if (!this.#paused || this.#released || this.#suspended) {
      return;
    }

    this.#paused = false;
    this.#listen();
    this.#shell.setNote(null);
  }

  showNote(): void {
    this.#shell.setNote(this.#strings.note.body);
  }

  /**
   * Hands the window over to whatever page comes next.
   *
   * Everything that could close it is disarmed from here on, because the
   * teardown that follows a page unloading would otherwise destroy the very
   * window the next page is about to adopt.
   */
  suspend(): void {
    if (this.#suspended) {
      return;
    }

    // A window nothing has recorded yet is not handed on, it is closed. The
    // stored placement is what sends the next page looking for a window, and
    // it does not say "window" until the panel has actually rendered into this
    // one — so leaving it standing would strand it with nobody ever coming.
    if (!this.#committed) {
      this.dispose();
      return;
    }

    this.#shell.setNote(this.#strings.note.body);
    this.#suspended = true;
    this.#ignore();
  }

  #closeWindow(): void {
    try {
      this.#window.close();
    } catch {
      // Nothing to do about a window we can no longer reach.
    }
  }

  #ignore(): void {
    const frame = this.#resizeFrame;
    this.#resizeFrame = undefined;
    this.#resizeGeneration++;

    // Separately, because a window we can no longer reach throws on the first
    // of these and the rest still have to happen.
    reachable(() =>
      this.#window.removeEventListener("pagehide", this.#onWindowPagehide)
    );
    reachable(() =>
      this.#window.removeEventListener("resize", this.#onWindowResize)
    );

    if (frame !== undefined) {
      reachable(() => this.#window.cancelAnimationFrame(frame));
    }
  }

  #listen(): void {
    reachable(() =>
      this.#window.addEventListener("pagehide", this.#onWindowPagehide)
    );
    reachable(() =>
      this.#window.addEventListener("resize", this.#onWindowResize)
    );
  }
}

/** How many probes a window gets before it is given up on. */
const CONNECT_TICKS = 60;

/** How long between probes, in milliseconds. */
const TICK_MS = 250;

/**
 * A window that has been asked for and is still arriving.
 *
 * It holds the key from the moment it is created, because the alternative is
 * that a second press opens a rival window onto the same name while the first
 * is still in flight.
 *
 * Readiness is settled by looking at the document, never by being told. The
 * shell posts a message when it loads, and that is taken only as a hint to
 * look now — a message cannot make an unready document ready, and cannot spend
 * the budget either, or unrelated traffic on the page would exhaust it.
 */
class PendingWindow implements PanelWindowConnection, Lease {
  readonly generation = ++lastGeneration;

  #cancelProbe?: () => void;
  #failedCallbacks: ((reason: PanelWindowFailure) => void)[] = [];
  #holder: PanelWindowHostBase;
  #key: string;
  #readyCallbacks: ((handle: PanelWindowHandle) => void)[] = [];
  #settled = false;
  #strings: PanelWindowStrings;
  #ticksLeft = CONNECT_TICKS;
  #window: Window;

  constructor(options: {
    holder: PanelWindowHostBase;
    key: string;
    strings: PanelWindowStrings;
    window: Window;
  }) {
    this.#holder = options.holder;
    this.#key = options.key;
    this.#strings = options.strings;
    this.#window = options.window;
    this.#armProbe();
  }

  get closed(): boolean {
    try {
      return this.#window.closed;
    } catch {
      return true;
    }
  }

  /** Whether a message came from the window this connection is waiting on. */
  wasSentBy(source: MessageEventSource | null): boolean {
    return source === this.#window;
  }

  /** Looks at the window now, without spending any of its budget. */
  probe(): void {
    if (this.#settled) {
      return;
    }

    if (this.closed) {
      this.#fail("closed");
      return;
    }

    const document = this.#holder.readDocument(this.#window);

    // Unreadable means the window is somewhere we are not allowed to look,
    // which our own route never is. It cannot become this panel's shell from
    // there, so waiting only leaves a stranger's page on the reader's screen.
    if (!document) {
      this.#fail("foreign");
      return;
    }

    const shell = adoptShell(document, this.#key);

    if (shell) {
      this.#succeed(shell);
      return;
    }

    // Arrived as something else: a login redirect, a 404, an error page. A
    // window that has not navigated yet is not this, and is left to keep
    // trying.
    if (hasArrived(document)) {
      this.#fail("foreign");
    }
  }

  /** Spends one probe of the budget. */
  spendTick(): void {
    if (this.#settled) {
      return;
    }

    this.probe();

    if (this.#settled) {
      return;
    }

    if (--this.#ticksLeft <= 0) {
      this.#fail("timeout");
      return;
    }

    this.#armProbe();
  }

  cancel(): void {
    if (this.#settled) {
      return;
    }

    this.#settled = true;
    this.#stopProbing();
    this.#release();

    if (!this.closed) {
      closeQuietly(this.#window);
    }

    this.#readyCallbacks = [];
    this.#failedCallbacks = [];
  }

  dispose(): void {
    this.cancel();
  }

  focus(): void {
    reachable(() => this.#window.focus());
  }

  onFailed(callback: (reason: PanelWindowFailure) => void): void {
    this.#failedCallbacks.push(callback);
  }

  onReady(callback: (handle: PanelWindowHandle) => void): void {
    this.#readyCallbacks.push(callback);
  }

  #armProbe(): void {
    this.#cancelProbe = this.#holder.scheduleProbe(
      this.#key,
      () => this.spendTick(),
      TICK_MS
    );
  }

  #fail(reason: PanelWindowFailure): void {
    this.#settled = true;
    this.#stopProbing();
    this.#release();

    // A window the reader already closed is not closed again: that is their
    // decision already carried out, and repeating it is a second close nobody
    // asked for.
    if (!this.closed) {
      closeQuietly(this.#window);
    }

    // Copied first: a caller is allowed to ask for another window from inside
    // this, and that must not append to the list being walked.
    const callbacks = this.#failedCallbacks;
    this.#failedCallbacks = [];
    this.#readyCallbacks = [];
    callbacks.forEach((callback) => callback(reason));
  }

  #release(): void {
    if (leases.get(this.#key) === this) {
      leases.delete(this.#key);
    }

    this.#holder.settled(this);
  }

  #stopProbing(): void {
    this.#cancelProbe?.();
    this.#cancelProbe = undefined;
  }

  #succeed(shell: PanelWindowShell): void {
    this.#settled = true;
    this.#stopProbing();
    this.#holder.settled(this);

    const handle = this.#holder.takeOver({
      generation: this.generation,
      key: this.#key,
      shell,
      strings: this.#strings,
      window: this.#window,
    });

    const callbacks = this.#readyCallbacks;
    this.#readyCallbacks = [];
    this.#failedCallbacks = [];
    callbacks.forEach((callback) => callback(handle));
  }
}

/**
 * The lease bookkeeping every host shares, independent of where the windows
 * themselves come from.
 *
 * Subclasses supply only the window; everything about leasing, suspension,
 * resumption and disposal lives here, so a test host exercises the real
 * lifecycle rather than a parallel one.
 */
export abstract class PanelWindowHostBase
  implements PanelWindowHost, LeaseHolder
{
  /** Ember instantiates a registered factory through this. */
  static create(): PanelWindowHostBase {
    return new (this as unknown as new () => PanelWindowHostBase)();
  }

  #connections = new Set<PendingWindow>();
  #handles = new Set<PanelWindow>();
  #listening = false;
  #onOpenerPagehide = (event: Event): void => {
    const persisted = (event as PageTransitionEvent).persisted;

    for (const handle of [...this.#handles]) {
      if (persisted) {
        handle.pause();
      } else {
        handle.suspend();
      }
    }

    // A window still arriving is nobody's to hand on. Nothing has recorded it,
    // and the page that asked for it is going away, so the only alternative to
    // closing it is leaving a blank window on the reader's screen for good.
    if (!persisted) {
      for (const connection of [...this.#connections]) {
        connection.cancel();
      }
    }
  };
  #onOpenerPageshow = (event: Event): void => {
    if (!(event as PageTransitionEvent).persisted) {
      return;
    }

    for (const handle of [...this.#handles]) {
      handle.resume();
    }
  };

  /**
   * A shell announcing itself, taken as a reason to look rather than as the
   * answer.
   *
   * It spends none of the connection's budget and carries no information we
   * act on, so traffic from anywhere else on the page costs one wasted look at
   * a document and can neither exhaust a window's budget nor make an unready
   * one ready.
   */
  #onOpenerMessage = (event: Event): void => {
    const source = (event as MessageEvent).source;

    for (const connection of [...this.#connections]) {
      if (connection.wasSentBy(source)) {
        connection.probe();
      }
    }
  };

  /** Releases every window this host still holds. */
  willDestroy(): void {
    for (const connection of [...this.#connections]) {
      connection.cancel();
    }

    for (const handle of [...this.#handles]) {
      handle.dispose();
    }

    this.#ignoreOpener();
  }

  /**
   * What tells the host that the page owning its windows is unloading or
   * coming back, through `pagehide` and `pageshow`.
   */
  abstract get openerEvents(): EventTarget;

  /**
   * How the framework releases a host it built, which is not the same name the
   * rest of the codebase reads as "let go of your resources".
   */
  destroy(): void {
    this.willDestroy();
  }

  /**
   * Opens this panel's window, revealing the one that already belongs to the
   * key rather than making a second.
   *
   * Takes the storage key rather than a window name because naming windows is
   * the concrete host's business, and there is no way to look a named window
   * up without opening one — which is exactly why
   * {@link PanelWindowHostBase.adopt} has to tell the two apart afterwards, by
   * the mark the shell leaves on the document.
   *
   * @returns The window, or `null` when it was refused.
   */
  abstract resolveWindow(
    key: string,
    resolution: WindowResolution
  ): Window | null;

  /**
   * Where a key's shell is served from.
   *
   * On the base rather than the browser host because it is the same page in
   * every environment; a host serving a stand-in overrides it.
   */
  shellUrlFor(key: string): string {
    const url = `/panel-window/${encodeURIComponent(key)}`;
    const carried = new URLSearchParams();

    // A window inherits the page's cookies but not its query string, and both
    // of these are chosen there — so without this the window renders the
    // committed theme while the page it belongs to is previewing another.
    const here = new URLSearchParams(window.location.search);
    for (const name of ["preview_theme_id", "safe_mode"]) {
      const value = here.get(name);
      if (value) {
        carried.set(name, value);
      }
    }

    const query = carried.toString();
    return getURL(query ? `${url}?${query}` : url);
  }

  /**
   * Reads a window's document, or `null` when it is somewhere we cannot look.
   *
   * A seam because `Window.document` cannot be replaced — the spec marks it
   * unforgeable — so a test with no cross-origin window to hand has nowhere
   * else to say "this one is out of reach".
   */
  readDocument(panelWindow: Window): Document | null {
    return readableDocument(panelWindow);
  }

  /**
   * Schedules the next look at a window that is still arriving.
   *
   * A seam rather than a bare timer so a test can drive a loading window one
   * probe at a time instead of waiting on a clock.
   *
   * @returns How to cancel the scheduled probe.
   */
  scheduleProbe(_key: string, run: () => void, delayMs: number): () => void {
    const token = setTimeout(run, delayMs);
    return () => clearTimeout(token);
  }

  adopt(key: string, strings: PanelWindowStrings): PanelWindowOutcome {
    if (heldLease(key)) {
      return { status: "already-leased" };
    }

    // Deliberately without a URL: naming an existing window with one navigates
    // it, and the whole point here is to find out what is already in it.
    const panelWindow = this.resolveWindow(key, { intent: "adopt" });
    const document = panelWindow ? this.readDocument(panelWindow) : null;

    if (!panelWindow || !document) {
      closeQuietly(panelWindow);
      return { status: "unavailable" };
    }

    // A window the browser has just made for us looks exactly like the one a
    // previous visit left behind, so the mark the server rendered is the only
    // thing separating adopting from stranding an empty window on the screen.
    if (shellKey(document) !== key) {
      closeQuietly(panelWindow);
      return { status: "unavailable" };
    }

    const shell = adoptShell(document, key);

    if (!shell) {
      closeQuietly(panelWindow);
      return { status: "unavailable" };
    }

    return {
      status: "acquired",
      handle: this.takeOver({ key, shell, strings, window: panelWindow }),
    };
  }

  open(
    key: string,
    strings: PanelWindowStrings,
    geometry?: PanelWindowGeometry | null
  ): PanelWindowOutcome {
    if (heldLease(key)) {
      return { status: "already-leased" };
    }

    const panelWindow = this.resolveWindow(key, {
      intent: "open",
      url: this.shellUrlFor(key),
      geometry,
    });

    // The one failure still answerable in the same breath as the gesture: a
    // blocked popup never becomes a window, so no lease is taken for it.
    if (!panelWindow) {
      return { status: "unavailable" };
    }

    const connection = new PendingWindow({
      holder: this,
      key,
      strings,
      window: panelWindow,
    });

    leases.set(key, connection);
    this.#connections.add(connection);
    this.#listenToOpener();

    return { status: "connecting", connection };
  }

  /** Turns a window that has finished arriving into the lease that holds it. */
  takeOver(options: {
    generation?: number;
    key: string;
    shell: PanelWindowShell;
    strings: PanelWindowStrings;
    window: Window;
  }): PanelWindowHandle {
    // The served page titles itself generically, because it is rendered before
    // anyone knows which panel it will hold. Naming it here is what lets two
    // panel windows be told apart in a window switcher.
    reachable(() => {
      options.shell.mount.ownerDocument.title = options.strings.title;
    });

    // The served page carries everything a server can know. What it cannot is
    // what this page derives at runtime — the CSS it generates, the icons it
    // has picked up since boot, and which colour scheme is live — so that much
    // is followed for as long as the window is held.
    const mirror = mirrorOpener(options.shell.mount.ownerDocument);
    const handle = new PanelWindow({ holder: this, mirror, ...options });

    leases.set(options.key, handle);
    this.#handles.add(handle);
    this.#listenToOpener();

    return handle;
  }

  /** Called by a connection once it has stopped holding anything. */
  settled(connection: PendingWindow): void {
    this.#connections.delete(connection);
    this.#releaseOpenerWhenIdle();
  }

  released(handle: PanelWindow): void {
    this.#handles.delete(handle);
    this.#releaseOpenerWhenIdle();
  }

  #releaseOpenerWhenIdle(): void {
    if (this.#handles.size === 0 && this.#connections.size === 0) {
      this.#ignoreOpener();
    }
  }

  #ignoreOpener(): void {
    if (!this.#listening) {
      return;
    }

    this.#listening = false;
    this.openerEvents.removeEventListener("pagehide", this.#onOpenerPagehide);
    this.openerEvents.removeEventListener("pageshow", this.#onOpenerPageshow);
    this.openerEvents.removeEventListener("message", this.#onOpenerMessage);
  }

  #listenToOpener(): void {
    if (this.#listening) {
      return;
    }

    this.#listening = true;
    this.openerEvents.addEventListener("pagehide", this.#onOpenerPagehide);
    this.openerEvents.addEventListener("pageshow", this.#onOpenerPageshow);
    this.openerEvents.addEventListener("message", this.#onOpenerMessage);
  }
}

/** The host that opens real browser windows. */
export default class BrowserWindowHost extends PanelWindowHostBase {
  get openerEvents(): EventTarget {
    return window;
  }

  resolveWindow(key: string, resolution: WindowResolution): Window | null {
    const name = windowNameFor(key);

    if (resolution.intent === "adopt") {
      // The empty URL is load-bearing: it reveals the window already under
      // this name without navigating it, which is what adoption depends on.
      return window.open("", name);
    }

    return window.open(
      resolution.url,
      name,
      windowFeaturesFor(resolution.geometry)
    );
  }
}

/**
 * The host every panel in one application shares.
 *
 * Looked up rather than constructed so a panel never has to know how windows
 * are made, and registered on first use so nothing has to install it during
 * boot. A test that registers its own host before the first lookup wins.
 */
export function windowHostFor(owner: Owner): PanelWindowHost {
  // Looked up before registering rather than asking whether a registration
  // exists: the public owner has no such question, and a lookup that resolves
  // nothing leaves the name free to register.
  const registered = owner.lookup(WINDOW_HOST_REGISTRATION);
  if (registered) {
    return registered as PanelWindowHost;
  }

  owner.register(WINDOW_HOST_REGISTRATION, BrowserWindowHost);
  return owner.lookup(WINDOW_HOST_REGISTRATION) as PanelWindowHost;
}

/** Closes a window we have decided not to keep, if it is still reachable. */
function closeQuietly(panelWindow: Window | null): void {
  try {
    panelWindow?.close();
  } catch {
    // A window we cannot reach is already as closed as we need it to be.
  }
}

/**
 * @returns The window's document, or `null` when there is none to read — a
 * window that navigated somewhere else is no longer ours to write into.
 */
/**
 * Whether a window has finished going somewhere.
 *
 * A window that was just opened sits on a blank document until the navigation
 * it was given commits, and that is not the same as having arrived somewhere
 * that is not ours — one is worth waiting for and the other is not.
 */
function hasArrived(doc: Document): boolean {
  try {
    return doc.readyState !== "loading" && doc.URL !== "about:blank";
  } catch {
    return false;
  }
}

function readableDocument(panelWindow: Window | null): Document | null {
  if (!panelWindow) {
    return null;
  }

  try {
    return panelWindow.document ?? null;
  } catch {
    return null;
  }
}

function windowFeaturesFor(geometry?: PanelWindowGeometry | null): string {
  const features = ["popup"];

  if (geometry) {
    if (isSize(geometry.width) && isSize(geometry.height)) {
      features.push(`width=${geometry.width}`, `height=${geometry.height}`);
    }

    // Passed through as measured, negative values included. `screen` describes
    // the display the page is on, not the whole desktop, so testing these
    // against it would throw away a good position on a second monitor. The
    // browser can see the real arrangement and clamps the window itself.
    if (Number.isFinite(geometry.left) && Number.isFinite(geometry.top)) {
      features.push(`left=${geometry.left}`, `top=${geometry.top}`);
    }
  }

  return features.join(",");
}

/** Whether a stored dimension is one a window could actually be opened at. */
function isSize(value: number): boolean {
  return Number.isFinite(value) && value > 0;
}

/** Runs cleanup that a window we may no longer be able to touch can refuse. */
function reachable(operation: () => void): void {
  try {
    operation();
  } catch {
    // A window that is gone has already forgotten whatever this was undoing.
  }
}

function windowNameFor(key: string): string {
  return `d-panel-dock:${key}`;
}
