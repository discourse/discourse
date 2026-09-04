/**
 * The seam between a panel and the separate browser window it can move into.
 *
 * A window is leased, not owned: the page that opened it holds exactly one
 * lease per storage key, so two panels sharing a key can never both drive the
 * same window, and a page that comes back after a reload can recognize the
 * window it left behind and take it over rather than opening a second one.
 *
 * The lease also outlives the page in one direction only. When the page goes
 * away for good the window stays open showing a note, because closing it would
 * destroy work the reader can still see; when the page is merely suspended the
 * window keeps its whole rendered tree and is resumed in place.
 */

import type Owner from "@ember/owner";
import {
  type PanelWindowNote,
  type PanelWindowSkeleton,
  skeletonKey,
  writeSkeleton,
} from "discourse/ui-kit/panel-dock/-internals/window-skeleton";

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
}

/**
 * What came of asking for a window.
 *
 * The three cases are deliberately distinct rather than a nullable handle,
 * because only `unavailable` means "there is no window to be had" and may
 * rewrite a stored layout. `already-leased` means another panel holds this
 * key and the caller must change nothing.
 */
export type PanelWindowOutcome =
  | { status: "acquired"; handle: PanelWindowHandle }
  | { status: "already-leased" }
  | { status: "unavailable" };

/** Supplies panel windows and holds the leases on them. */
export interface PanelWindowHost {
  /**
   * Opens a new window. Must be called synchronously from the gesture that
   * asked for it, or the browser will refuse it.
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
const leases = new Map<string, PanelWindow>();

let lastGeneration = 0;

/**
 * The handle currently holding a key, if one still has anything to hold.
 *
 * A window the reader closed leaves its handle behind until the panel notices,
 * and treating that as a live lease would strand the key for the rest of the
 * page's life. Reaping it here means asking for a window is always answerable.
 */
function heldLease(key: string): PanelWindow | undefined {
  const handle = leases.get(key);

  if (!handle) {
    return undefined;
  }

  if (handle.closed) {
    handle.dispose();
    return undefined;
  }

  return handle;
}

/** How a leased window reports back to the host holding it. */
interface LeaseHolder {
  /** Called once the handle has let go of its window. */
  released(handle: PanelWindow): void;
}

/**
 * One leased window.
 *
 * Not exported: a caller only ever meets it as a {@link PanelWindowHandle},
 * and the extra members here are how the host drives it through the opening
 * page's own lifecycle.
 */
class PanelWindow implements PanelWindowHandle {
  readonly generation = ++lastGeneration;
  readonly mount: HTMLElement;

  #holder: LeaseHolder;
  #key: string;
  #pagehideCallbacks: (() => void)[] = [];
  #paused = false;
  #released = false;
  #resizeCallbacks: (() => void)[] = [];
  #resizeFrame?: number;
  #resizeGeneration = 0;
  #skeleton: PanelWindowSkeleton;
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
    holder: LeaseHolder;
    key: string;
    skeleton: PanelWindowSkeleton;
    strings: PanelWindowStrings;
    window: Window;
  }) {
    this.#holder = options.holder;
    this.#key = options.key;
    this.#skeleton = options.skeleton;
    this.#strings = options.strings;
    this.#window = options.window;
    this.mount = options.skeleton.mount;
    this.#listen();
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

    this.#skeleton.setNote(null);
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
      this.#skeleton.dispose();
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
    this.#skeleton.setNote(this.#strings.note);
  }

  /** Reports again to a page that came back, under the same lease. */
  resume(): void {
    if (!this.#paused || this.#released || this.#suspended) {
      return;
    }

    this.#paused = false;
    this.#listen();
    this.#skeleton.setNote(null);
  }

  showNote(): void {
    this.#skeleton.setNote(this.#strings.note);
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

    this.#skeleton.setNote(this.#strings.note);
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

  #handles = new Set<PanelWindow>();
  #listening = false;
  #onOpenerPagehide = (event: Event): void => {
    for (const handle of [...this.#handles]) {
      if ((event as PageTransitionEvent).persisted) {
        handle.pause();
      } else {
        handle.suspend();
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

  /** Releases every window this host still holds. */
  willDestroy(): void {
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
    geometry?: PanelWindowGeometry | null
  ): Window | null;

  adopt(key: string, strings: PanelWindowStrings): PanelWindowOutcome {
    if (heldLease(key)) {
      return { status: "already-leased" };
    }

    const panelWindow = this.resolveWindow(key);
    const document = readableDocument(panelWindow);

    if (!panelWindow || !document) {
      closeQuietly(panelWindow);
      return { status: "unavailable" };
    }

    // A window the browser has just made for us looks exactly like the one a
    // previous visit left behind, so the mark is the only thing that separates
    // adopting from stranding an empty window on the reader's screen.
    if (skeletonKey(document) !== key) {
      closeQuietly(panelWindow);
      return { status: "unavailable" };
    }

    return this.#lease(key, panelWindow, document, strings);
  }

  open(
    key: string,
    strings: PanelWindowStrings,
    geometry?: PanelWindowGeometry | null
  ): PanelWindowOutcome {
    if (heldLease(key)) {
      return { status: "already-leased" };
    }

    const panelWindow = this.resolveWindow(key, geometry);
    const document = readableDocument(panelWindow);

    if (!panelWindow || !document) {
      closeQuietly(panelWindow);
      return { status: "unavailable" };
    }

    return this.#lease(key, panelWindow, document, strings);
  }

  released(handle: PanelWindow): void {
    this.#handles.delete(handle);

    if (this.#handles.size === 0) {
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
  }

  #lease(
    key: string,
    panelWindow: Window,
    document: Document,
    strings: PanelWindowStrings
  ): PanelWindowOutcome {
    const skeleton = writeSkeleton(document, key, strings.title);
    const handle = new PanelWindow({
      holder: this,
      key,
      skeleton,
      strings,
      window: panelWindow,
    });

    leases.set(key, handle);
    this.#handles.add(handle);
    this.#listenToOpener();

    return { status: "acquired", handle };
  }

  #listenToOpener(): void {
    if (this.#listening) {
      return;
    }

    this.#listening = true;
    this.openerEvents.addEventListener("pagehide", this.#onOpenerPagehide);
    this.openerEvents.addEventListener("pageshow", this.#onOpenerPageshow);
  }
}

/** The host that opens real browser windows. */
export default class BrowserWindowHost extends PanelWindowHostBase {
  get openerEvents(): EventTarget {
    return window;
  }

  resolveWindow(
    key: string,
    geometry?: PanelWindowGeometry | null
  ): Window | null {
    return window.open("", windowNameFor(key), windowFeaturesFor(geometry));
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
