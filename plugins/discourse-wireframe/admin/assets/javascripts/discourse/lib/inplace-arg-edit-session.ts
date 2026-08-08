import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import type { LayoutEntry } from "discourse/blocks/types";
import type WireframeInplaceTextService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-inplace-text";
import type WireframeLayoutQueryService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-query";
import type WireframeMutationEngineService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-mutation-engine";

/** Identifies the block argument edited by an in-place session. */
export interface InplaceArgEditTarget {
  /** Name of the argument being edited. */
  argName: string;
  /** Composite key of the block that owns the argument. */
  blockKey: string;
}

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
  /** Records the final argument change and its undo entry. */
  @service declare wireframeMutationEngine: WireframeMutationEngineService;
  /** Commits any active text edit before another inline editor opens. */
  @service declare wireframeInplaceText: WireframeInplaceTextService;
  /** Resolves the entry and outlet that own the edited argument. */
  @service declare wireframeLayoutQuery: WireframeLayoutQueryService;

  /**
   * Currently-editing block key. `null` when no session is active.
   *
   */
  @tracked blockKey: string | null = null;

  /**
   * Currently-editing arg name. `null` when no session is active.
   *
   */
  @tracked argName: string | null = null;

  /**
   * Cached entry + outlet for the session so `#recordEdit` doesn't re-walk the
   * layout. Cleared by `clearState`.
   *
   */
  #located: {
    /** Resolved layout entry that owns the argument. */
    entry: LayoutEntry;
    /** Outlet containing the resolved entry. */
    outletName: string;
  } | null = null;

  /**
   * Snapshot of the arg's pre-edit value, captured at `openSession` time so the
   * eventual undo entry records the session's net change.
   *
   */
  #prevValue: unknown = null;

  /**
   * The pre-edit snapshot, exposed read-only so a subclass can seed its surface
   * (e.g. the icon picker's initial selection) without reaching the private
   * field.
   *
   * @returns The value the argument held when the session opened.
   */
  get prevValue(): unknown {
    return this.#prevValue;
  }

  /**
   * Begins a session for `(blockKey, argName)` — the default (popover) flow with
   * no anchored surface to open. Captures the pre-edit snapshot so the eventual
   * undo entry records the net change.
   *
   * @param target - Block and argument that should enter edit mode.
   */
  start({ blockKey, argName }: InplaceArgEditTarget): void {
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
   * @param value - New argument value, or `null` to remove it.
   */
  applyChange(value: string | null): void {
    if (this.#recordEdit(value)) {
      this.stop();
    }
  }

  /**
   * Closes the session without writing back. Idempotent.
   */
  stop(): void | Promise<void> {
    this.clearState();
  }

  /**
   * Commits any in-flight rich-text inline edit before this session begins,
   * honoring the in-place text session-boundary contract. Part of the base's
   * extension surface (a subclass `start` override calls it).
   */
  closeInplaceText(): void {
    if (this.wireframeInplaceText.blockKey) {
      this.wireframeInplaceText.stop({ commit: true });
    }
  }

  /**
   * Locates the target entry and captures the pre-edit snapshot. Assumes any
   * prior session has already been closed. Part of the base's extension surface
   * (a subclass `start` override calls it).
   *
   * @param target - Block and argument whose current value should be captured.
   * @returns `true` when the key resolved and a session opened.
   */
  openSession({ blockKey, argName }: InplaceArgEditTarget): boolean {
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
  clearState(): void {
    this.#located = null;
    this.#prevValue = null;
    this.blockKey = null;
    this.argName = null;
  }

  /**
   * Records the active session's net change as a single `{ kind: "args" }` undo
   * entry. No-op when no session is active.
   *
   * @param value - New argument value, or `null` to remove it.
   * @returns `true` when an active session was recorded.
   */
  #recordEdit(value: string | null): boolean {
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
