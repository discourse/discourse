// @ts-check
import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";

/**
 * Shared base for the in-place single-arg edit sessions — editing one block-arg
 * by interacting with how it is rendered on the canvas, as opposed to the
 * inspector panel. Two services extend it: the URL-edit popover
 * (`WireframeInplaceLinkService`) and the icon-picker menu
 * (`WireframeInplaceIconService`). They share all of the session bookkeeping —
 * which `(blockKey, argName)` is in flight, the pre-edit snapshot, the
 * mutation/undo recording, and the rich-text session boundary — and differ only
 * in the FloatKit surface they host.
 *
 * This class is NOT registered as a service. It lives in `lib/` so Ember never
 * resolves it directly; the registered services in `services/` extend it, and
 * the `@service` injections declared here are inherited by those subclasses.
 *
 * Subclasses customize the surface by overriding `start` (open the anchored UI)
 * and, when the surface needs async teardown, `stop` / `clearState`. The shared
 * preamble (`closeInplaceText`), session open (`openSession`), and state reset
 * (`clearState`) are the base's extension surface — unprefixed because a
 * subclass calls them, and a `#`-private member is unreachable from a subclass.
 * Edit recording stays truly private (`#recordEdit`): only the base's own
 * `applyChange` uses it.
 */
export default class InplaceArgEditSession extends Service {
  @service wireframeMutationEngine;
  @service wireframeInplaceText;
  @service wireframeLayoutQuery;

  /**
   * Currently-editing block key. `null` when no session is active.
   *
   * @type {string|null}
   */
  @tracked blockKey = null;

  /**
   * Currently-editing arg name. `null` when no session is active.
   *
   * @type {string|null}
   */
  @tracked argName = null;

  /**
   * Cached entry + outlet for the session so `#recordEdit` doesn't re-walk the
   * layout. Cleared by `clearState`.
   *
   * @type {{entry: Object, outletName: string}|null}
   */
  #located = null;

  /**
   * Snapshot of the arg's pre-edit value, captured at `openSession` time so the
   * eventual undo entry records the session's net change.
   *
   * @type {*}
   */
  #prevValue = null;

  /**
   * The pre-edit snapshot, exposed read-only so a subclass can seed its surface
   * (e.g. the icon picker's initial selection) without reaching the private
   * field.
   *
   * @returns {*} The value the arg held when the session opened.
   */
  get prevValue() {
    return this.#prevValue;
  }

  /**
   * Begins a session for `(blockKey, argName)` — the default (popover) flow with
   * no anchored surface to open. Captures the pre-edit snapshot so the eventual
   * undo entry records the net change.
   *
   * @param {{blockKey: string, argName: string}} args
   */
  start({ blockKey, argName }) {
    this.closeInplaceText();
    if (this.blockKey) {
      this.stop();
    }
    this.openSession({ blockKey, argName });
  }

  /**
   * Writes `value` into the arg through the mutation/undo engine (a single net
   * undo entry) and closes the session. No-op when no session is active.
   *
   * @param {string|null} value
   */
  applyChange(value) {
    if (this.#recordEdit(value)) {
      this.stop();
    }
  }

  /**
   * Closes the session without writing back. Idempotent.
   */
  stop() {
    this.clearState();
  }

  /**
   * Commits any in-flight rich-text inline edit before this session begins,
   * honoring the in-place text session-boundary contract. Part of the base's
   * extension surface (a subclass `start` override calls it).
   */
  closeInplaceText() {
    if (this.wireframeInplaceText.blockKey) {
      this.wireframeInplaceText.stop({ commit: true });
    }
  }

  /**
   * Locates the target entry and captures the pre-edit snapshot. Assumes any
   * prior session has already been closed. Part of the base's extension surface
   * (a subclass `start` override calls it).
   *
   * @param {{blockKey: string, argName: string}} args
   * @returns {boolean} `true` if a session opened (the key resolved).
   */
  openSession({ blockKey, argName }) {
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(blockKey);
    if (!located) {
      return false;
    }

    this.blockKey = blockKey;
    this.argName = argName;
    this.#located = located;
    this.#prevValue = located.entry.args?.[argName] ?? null;
    return true;
  }

  /**
   * Resets the session state. Subclasses override to also clear their own UI
   * handles, calling `super.clearState()`.
   */
  clearState() {
    this.#located = null;
    this.#prevValue = null;
    this.blockKey = null;
    this.argName = null;
  }

  /**
   * Records the active session's net change as a single `{ kind: "args" }` undo
   * entry. No-op when no session is active.
   *
   * @param {string|null} value
   * @returns {boolean} `true` if an edit was recorded (a session was active).
   */
  #recordEdit(value) {
    const located = this.#located;
    const argName = this.argName;
    if (!located || !argName) {
      return false;
    }

    const { entry, outletName } = located;
    this.wireframeMutationEngine.recordArgEdit({
      entry,
      outletName,
      argName,
      prevValue: this.#prevValue,
      nextValue: value || null,
    });
    return true;
  }
}
