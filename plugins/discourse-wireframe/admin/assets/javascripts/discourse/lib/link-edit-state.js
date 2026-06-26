// @ts-check
import { tracked } from "@glimmer/tracking";

/**
 * Owns the state of an inline URL-edit session for a block-arg: which
 * (blockKey, argName) is being edited, plus the pre-edit snapshot used
 * to push a single undo entry on commit.
 *
 * The UI lives in the anchored `LinkEditPopover` (a FloatKit tooltip
 * registered on each rendered link element) which calls `start` on
 * editing, `applyChange` on confirm, and `stop` on cancel / unmount.
 * The popover renders its own input — this state object only tracks
 * which (blockKey, argName) is in flight and the pre-edit snapshot.
 *
 * Plain JS class — NOT an Ember service. Instantiated once per service
 * instance at service construction and exposed via `wireframe.linkEdit`.
 */
export default class LinkEditState {
  /**
   * Currently-editing block key. `null` when no session is active.
   *
   * @type {string|null}
   */
  @tracked blockKey = null;

  /**
   * Currently-editing arg name (e.g. `"href"`, `"linkHref"`,
   * `"ctaHref"`, `"link"`).
   *
   * @type {string|null}
   */
  @tracked argName = null;

  /**
   * Cached entry + outlet for the session so `applyChange` doesn't
   * re-walk the layout. Cleared by `stop`.
   *
   * @type {{entry: Object, outletName: string}|null}
   */
  #located = null;

  /**
   * Snapshot of the arg's pre-edit value, captured at `start` time so
   * `applyChange` can push a single `{ kind: "args" }` undo entry
   * capturing the net change.
   *
   * @type {*}
   */
  #prevValue = null;

  /**
   * @param {import("../services/wireframe").default} service
   */
  constructor(service) {
    this.service = service;
  }

  /**
   * Begins a URL-edit session for `(blockKey, argName)`. Captures the
   * current value as the pre-edit snapshot so the eventual undo entry
   * records the net change.
   *
   * Implicitly commits any rich-text inline-edit in flight, matching
   * the inline-edit session boundary contract.
   *
   * @param {{blockKey: string, argName: string}} args
   */
  start({ blockKey, argName }) {
    if (this.service.inlineEdit.blockKey) {
      this.service.inlineEdit.stop({ commit: true });
    }
    if (this.blockKey) {
      this.stop();
    }

    const located = this.service.layoutQuery.findEntryAndOutletSync(blockKey);
    if (!located) {
      return;
    }

    this.blockKey = blockKey;
    this.argName = argName;
    this.#located = located;
    this.#prevValue = located.entry.args?.[argName] ?? null;
  }

  /**
   * Writes the URL into `entry.args[argName]` and pushes a single
   * undo entry capturing the session's net change. Closes the session
   * via `stop`.
   *
   * @param {string|null} value
   */
  applyChange(value) {
    const located = this.#located;
    const argName = this.argName;
    if (!located || !argName) {
      return;
    }
    const { entry, outletName } = located;
    this.service.editedOutlets.add(outletName);
    const prevMap = new Map([[argName, this.#prevValue]]);
    this.service.captureInitialSnapshot(entry, prevMap);
    this.service.writeArgs(entry, new Map([[argName, value || null]]));

    if (this.#prevValue !== (value || null)) {
      this.service.undoStack.push({
        kind: "args",
        entry,
        prev: prevMap,
        next: new Map([[argName, value || null]]),
      });
      this.service.redoStack.length = 0;
    }

    this.stop();
  }

  /**
   * Closes the URL-edit session without writing back. Idempotent.
   */
  stop() {
    this.#located = null;
    this.#prevValue = null;
    this.blockKey = null;
    this.argName = null;
  }
}
