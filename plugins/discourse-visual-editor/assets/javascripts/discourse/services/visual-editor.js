// @ts-check
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";

/**
 * Phase 1 editor service. Holds the editor's session state and exposes the
 * gating logic that the entry pill and chrome consult.
 *
 * Reactivity contract: every `@tracked` field on this service is read by the
 * panels and the canvas chrome. Mutating one re-renders the relevant pieces
 * via Glimmer's tracking system without manual notification.
 *
 * The Phase 1 surface is intentionally narrow:
 *   - `isActive` toggles editor mode (the chrome appears or hides).
 *   - `selectedBlockKey` identifies the currently selected block by its
 *     stable composite key, formatted as `${blockName}:${__stableKey}` to
 *     match the key minted in `frontend/discourse/app/lib/blocks/-internals/entry-processing.js`.
 *     The same key surfaces through the BLOCK_DEBUG payload so canvas chrome
 *     and outline rows compare apples to apples.
 *   - `selectedBlockData` carries enough metadata to render the inspector
 *     without re-walking the layout.
 *
 * Persistence, mutation, and drag-drop are out of scope for Phase 1.
 */
export default class VisualEditorService extends Service {
  @service blocks;
  @service currentUser;
  @service siteSettings;

  @tracked isActive = false;
  @tracked selectedBlockKey = null;

  /**
   * Snapshot of the selected block populated by either the canvas chrome
   * (on click) or the outline panel (on row click). The shape is a loose
   * subset of `{ key, name, id, args, containerArgs, conditions, outletArgs,
   * outletName, metadata }`. Some fields are only available from one entry
   * point — for example, `containerArgs` and `outletArgs` are only set when
   * the selection comes from a rendered block on the canvas.
   */
  @tracked selectedBlockData = null;

  /**
   * Whether the current user is allowed to use the editor. Staff are always
   * allowed. Non-staff users must belong to at least one of the groups listed
   * in the `visual_editor_allowed_groups` site setting. The plugin must also
   * be enabled via `visual_editor_enabled`.
   *
   * @returns {boolean}
   */
  get canEdit() {
    if (!this.siteSettings.visual_editor_enabled) {
      return false;
    }
    if (!this.currentUser) {
      return false;
    }
    if (this.currentUser.staff) {
      return true;
    }
    // Group-list site settings serialize as a pipe-delimited string of
    // group ids ("1|11|41"). Empty values produce empty strings, hence the
    // filter to drop them.
    const allowed = (this.siteSettings.visual_editor_allowed_groups || "")
      .split("|")
      .filter(Boolean);
    if (allowed.length === 0) {
      return false;
    }
    const userGroupIds = (this.currentUser.groups || []).map((g) =>
      String(g.id)
    );
    return allowed.some((id) => userGroupIds.includes(String(id)));
  }

  /**
   * The names of every block outlet that has a layout registered right now.
   * The entry pill uses this to decide whether to appear and what count to
   * display. Sourced from `services/blocks` so the registry is the single
   * source of truth.
   *
   * @returns {string[]}
   */
  get editableOutlets() {
    return this.blocks
      .listOutlets()
      .filter((name) => this.blocks.hasLayout(name));
  }

  @action
  enter() {
    if (!this.canEdit) {
      return;
    }
    this.isActive = true;
    document.body.classList.add("visual-editor-active");
  }

  @action
  exit() {
    this.isActive = false;
    this.selectedBlockKey = null;
    this.selectedBlockData = null;
    document.body.classList.remove("visual-editor-active");
  }

  @action
  toggle() {
    if (this.isActive) {
      this.exit();
    } else {
      this.enter();
    }
  }

  @action
  selectBlock(data) {
    this.selectedBlockKey = data?.key ?? null;
    this.selectedBlockData = data ?? null;
  }

  /**
   * Tells whether a given block key matches the current selection.
   *
   * Decorated with `@action` so that Glimmer template subexpressions like
   * `(this.visualEditor.isBlockSelected row.blockKey)` keep the correct
   * `this` binding. Without it Glimmer extracts the bare function reference
   * and calls it without context, which throws when the body reads
   * `this.selectedBlockKey`.
   *
   * @param {string|null} key - The composite block key (`${name}:${__stableKey}`).
   * @returns {boolean}
   */
  @action
  isBlockSelected(key) {
    return this.selectedBlockKey != null && this.selectedBlockKey === key;
  }
}
