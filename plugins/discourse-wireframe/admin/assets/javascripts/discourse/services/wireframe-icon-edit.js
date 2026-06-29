// @ts-check
import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import IconEditPopover from "../components/icon-edit-popover";

/**
 * Owns the state of an inline icon-edit session: which (blockKey,
 * argName) is being edited, the pre-edit snapshot for undo, and the
 * open FloatKit menu instance hosting the icon picker.
 *
 * A peer command service in the editor's acyclic graph: it injects the
 * menu service (hosts the picker), the read-only layout query layer
 * (entry lookup), the mutation/undo engine (records the arg edit), and
 * the inline rich-text edit session (closed on start as a session
 * boundary). The UI lives in `IconEditPopover`, mounted via the menu;
 * this service only tracks the session metadata.
 */
export default class WireframeIconEditService extends Service {
  @service menu;
  @service wireframeEditEngine;
  @service wireframeInlineEdit;
  @service wireframeLayoutQuery;

  /**
   * Currently-editing block key. `null` when no session is active.
   *
   * @type {string|null}
   */
  @tracked blockKey = null;

  /**
   * Currently-editing arg name (e.g. `"icon"`, `"badgeIcon"`). `null`
   * when no session is active.
   *
   * @type {string|null}
   */
  @tracked argName = null;

  /**
   * Cached entry + outlet for the session so we don't re-walk the
   * layout to commit. Cleared by `stop`.
   *
   * @type {{entry: Object, outletName: string}|null}
   */
  #located = null;

  /**
   * Snapshot of the arg's pre-edit value, captured at `start` time so
   * we can push a single `{ kind: "args" }` undo entry on commit.
   *
   * @type {*}
   */
  #prevValue = null;

  /**
   * The open FloatKit menu instance, returned by `menu.show(...)`.
   * Closed by `stop`. Tracked separately so we can close it from
   * paths that don't have the menu API in scope.
   *
   * @type {*}
   */
  #menuInstance = null;

  /**
   * Begins an icon-edit session for `(blockKey, argName)`. Captures
   * the current value as the pre-edit snapshot and opens a FloatKit
   * menu anchored to `anchorEl` with the icon picker inside.
   *
   * The picker calls `applyChange` with the new icon id on user
   * selection. Clicking outside the popover closes it via FloatKit's
   * default behavior; that path invokes `stop` through the menu's
   * `onClose` callback so the session state is cleared.
   *
   * Implicitly commits + ends any rich-text inline-edit in flight —
   * a second click on a different field is a session boundary,
   * matching the rich-text editor's own contract.
   *
   * @param {{blockKey: string, argName: string, anchorEl: HTMLElement}} args
   * @returns {Promise<void>}
   */
  async start({ blockKey, argName, anchorEl }) {
    // Close any other inline-edit session first.
    if (this.wireframeInlineEdit.blockKey) {
      this.wireframeInlineEdit.stop({ commit: true });
    }
    if (this.blockKey) {
      await this.stop();
    }

    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(blockKey);
    if (!located) {
      return;
    }

    this.blockKey = blockKey;
    this.argName = argName;
    this.#located = located;
    this.#prevValue = located.entry.args?.[argName] ?? null;

    this.#menuInstance = await this.menu.show(anchorEl, {
      // Match the public `DIconGridPicker`'s identifier / groupIdentifier /
      // maxWidth so the picker's CSS rules (`.fk-d-menu.d-icon-grid-picker-content
      // { --icon-grid-columns: 12; … }`) cascade and the grid lays out
      // correctly. Without this the picker collapses to a single column.
      identifier: "d-icon-grid-picker",
      groupIdentifier: "d-icon-grid-picker",
      maxWidth: 490,
      // `component:` (not `content:`) is what `d-menu.gjs` reads to render
      // a Glimmer component with `@data` injected. The service's JSDoc
      // mentions `options.content` accepting a Component, but the template
      // string-interpolates `content` instead of mounting it, so callbacks
      // and `@data` never reach the picker.
      component: IconEditPopover,
      placement: "bottom-start",
      fallbackPlacements: ["top-start", "bottom-end", "top-end"],
      data: {
        value: this.#prevValue ?? "",
        onSelect: (iconId) => this.applyChange(iconId),
      },
      onClose: () => this.#onMenuClosed(),
    });
  }

  /**
   * Writes the picked icon id into `entry.args[argName]` and pushes
   * a single undo entry capturing the session's net change. Closes
   * the popover.
   *
   * @param {string|null} value - The new icon id (or `null` / `""`
   *   to clear).
   */
  applyChange(value) {
    const located = this.#located;
    const argName = this.argName;
    if (!located || !argName) {
      return;
    }
    const { entry, outletName } = located;
    this.wireframeEditEngine.recordArgEdit({
      entry,
      outletName,
      argName,
      prevValue: this.#prevValue,
      nextValue: value || null,
    });

    // Close the popover; `#onMenuClosed` clears the session state.
    this.#menuInstance?.close();
  }

  /**
   * Closes the popover without writing back. Idempotent.
   *
   * @returns {Promise<void>}
   */
  async stop() {
    const instance = this.#menuInstance;
    if (instance) {
      await instance.close();
    } else {
      this.#clearSession();
    }
  }

  /**
   * Called by the menu's `onClose` callback so paths that close the
   * popover externally (click-outside, ESC, etc.) still clear our
   * session state.
   */
  #onMenuClosed() {
    this.#clearSession();
  }

  #clearSession() {
    this.#menuInstance = null;
    this.#located = null;
    this.#prevValue = null;
    this.blockKey = null;
    this.argName = null;
  }
}
