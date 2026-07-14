// @ts-check

import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";

/**
 * Holds the editor session's "is the editor open" signal plus the "is the
 * current user allowed to edit" eligibility check. Entering the editor raises
 * `active` and exiting lowers it; the many surfaces that show only while editing
 * (the shell, the entry pill, block chrome, the file-drag guard, …) read
 * `active` to gate themselves, and the entry point reads `canEdit` to decide
 * whether a session may open at all.
 *
 * It exists as its own peer service rather than living on the orchestrator because
 * concerns that are themselves services (e.g. image-upload's window-level
 * file-drag guard) need to read it, and reaching back into the orchestrator for it
 * would form a cycle. A standalone signal everyone reads downward keeps the
 * graph acyclic.
 */
export default class WireframeEditModeService extends Service {
  @service currentUser;
  @service siteSettings;

  // The session flag. `_`-prefixed because `@tracked` can't decorate a `#`
  // field and it's read only through the `active` getter — never written from
  // outside `activate` / `deactivate`.
  @tracked _active = false;

  /**
   * Whether the current user is allowed to use the editor. Staff are always
   * allowed. Non-staff users must belong to at least one of the groups listed
   * in the `wireframe_allowed_groups` site setting. The plugin must also be
   * enabled via `wireframe_enabled`.
   *
   * @returns {boolean}
   */
  get canEdit() {
    if (!this.siteSettings.wireframe_enabled) {
      return false;
    }
    if (!this.currentUser) {
      return false;
    }
    if (this.currentUser.staff) {
      return true;
    }
    // Group-list site settings serialize as a pipe-delimited string of group
    // ids ("1|11|41"). Empty values produce empty strings, hence the filter.
    const allowed = (this.siteSettings.wireframe_allowed_groups || "")
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
   * Whether an editor session is currently open. Read this in a getter/template
   * to re-run when the session opens or closes. Read-only: callers change it via
   * `activate` / `deactivate`, never by assigning.
   *
   * @returns {boolean}
   */
  get active() {
    return this._active;
  }

  /**
   * Marks the editor session open.
   */
  activate() {
    this._active = true;
  }

  /**
   * Marks the editor session closed.
   */
  deactivate() {
    this._active = false;
  }
}
