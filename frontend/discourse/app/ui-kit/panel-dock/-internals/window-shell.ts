/**
 * Taking over the shell a panel window was served with.
 *
 * The window is no longer written by the page that opens it: it arrives with
 * its markup already in place, possibly still parsing, possibly not a panel
 * window at all. So the job here is recognition and adoption, not construction.
 */

import interceptClick from "discourse/lib/intercept-click";

const WRAPPER_SELECTOR = ".d-panel-dock-window";
const MOUNT_SELECTOR = ".d-panel-dock-window__mount";
const NOTE_SELECTOR = ".d-panel-dock-window__reconnecting";
const STATUS_SELECTOR = "[role='status']";
const OUTLET_SELECTOR = "#d-menu-portals, #d-tooltip-portals";
const RECONNECTING_CLASS = "is-reconnecting";

/**
 * TODO(typescript-pending): Remove this boundary when the click interceptor is
 * authored in TypeScript.
 */
const handleInterceptedClick = interceptClick as (event: MouseEvent) => void;

/** An adopted panel window, for as long as the opening page owns it. */
export interface PanelWindowShell {
  /** The element the panel's tree renders into. */
  readonly mount: HTMLElement;

  /**
   * Shows the given sentence in place of the panel, or clears it with `null`.
   *
   * The mount is hidden rather than emptied, so a tree still rendered into it
   * survives and reappears when the note is cleared. The sentence is written at
   * the moment of the event because a live region that already holds its text
   * and is merely unhidden does not announce.
   */
  setNote(body: string | null): void;

  /**
   * Removes every listener this adoption installed, leaving the window's markup
   * as it stands. Safe to call more than once.
   */
  dispose(): void;
}

/**
 * The context key the given document was served for.
 *
 * @returns The key, or `undefined` when the document is not a panel window.
 */
export function shellKey(doc: Document): string | undefined {
  return doc.documentElement.dataset.dPanelDock;
}

/**
 * Whether the document is this panel's shell and is far enough along to adopt.
 *
 * A document mid-parse carries the marker on `<html>` long before it has the
 * body the marker promises, so the marker alone cannot be the gate.
 */
export function shellReady(doc: Document, key: string): boolean {
  return shellKey(doc) === key && !!doc.querySelector(MOUNT_SELECTOR);
}

/**
 * Takes over a served shell so the opening page can render into it.
 *
 * Validates before it writes anything, so a caller may probe the same document
 * repeatedly while it loads without damaging a page that is not ours.
 *
 * @param doc - The window's document.
 * @param key - The context the window was served for.
 * @returns The shell, or `null` when the document is not this panel's window.
 */
export function adoptShell(
  doc: Document,
  key: string
): PanelWindowShell | null {
  const mount =
    shellKey(doc) === key
      ? doc.querySelector<HTMLElement>(MOUNT_SELECTOR)
      : null;

  if (!mount) {
    return null;
  }

  const wrapper = doc.querySelector(WRAPPER_SELECTOR);
  const note = doc.querySelector(NOTE_SELECTOR);
  const status = note?.querySelector(STATUS_SELECTOR) ?? null;

  mount.replaceChildren();
  // The float outlets sit outside the mount, so a previous page's menu or
  // tooltip would otherwise survive the takeover.
  for (const outlet of doc.querySelectorAll(OUTLET_SELECTOR)) {
    outlet.replaceChildren();
  }

  mount.addEventListener("click", handleInterceptedClick);
  let disposed = false;

  return {
    mount,

    setNote(body: string | null): void {
      if (status) {
        status.textContent = body ?? "";
      }

      if (body === null) {
        note?.setAttribute("hidden", "");
        wrapper?.classList.remove(RECONNECTING_CLASS);
      } else {
        note?.removeAttribute("hidden");
        wrapper?.classList.add(RECONNECTING_CLASS);
      }
    },

    dispose(): void {
      if (disposed) {
        return;
      }
      disposed = true;
      mount.removeEventListener("click", handleInterceptedClick);
    },
  };
}
