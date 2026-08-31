import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import type User from "discourse/models/user";
import type SiteSettingsService from "discourse/services/site-settings";

// TODO(devxp-typescript-pending): replace this local augmentation once core
// exposes a typed extension mechanism for plugin site settings.
interface WireframeSiteSettingsService extends SiteSettingsService {
  /** Whether the wireframe editor is enabled. */
  wireframe_enabled: boolean;
}

interface CurrentUserService extends User {
  /** Whether the server authorizes this user to open the wireframe editor. */
  can_use_wireframe: boolean;
}

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
  /** Signed-in user with the server-computed editor capability. */
  @service declare currentUser: CurrentUserService | null;
  /** Plugin settings that enable and scope editor access. */
  @service declare siteSettings: WireframeSiteSettingsService;

  /**
   * Internal editor-session flag, exposed read-only through `active` because
   * tracked fields cannot use JavaScript private-field syntax.
   */
  @tracked _active = false;

  /**
   * Whether the current user is allowed to use the editor. Staff are always
   * allowed; for everyone else, the server computes the capability from
   * complete group membership. The plugin must also be enabled via
   * `wireframe_enabled`.
   *
   */
  get canEdit(): boolean {
    if (!this.siteSettings.wireframe_enabled) {
      return false;
    }
    if (!this.currentUser) {
      return false;
    }
    if (this.currentUser.staff) {
      return true;
    }
    return this.currentUser.can_use_wireframe;
  }

  /**
   * Whether an editor session is currently open. Read this in a getter/template
   * to re-run when the session opens or closes. Read-only: callers change it via
   * `activate` / `deactivate`, never by assigning.
   *
   */
  get active(): boolean {
    return this._active;
  }

  /**
   * Marks the editor session open.
   */
  activate(): void {
    this._active = true;
  }

  /**
   * Marks the editor session closed.
   */
  deactivate(): void {
    this._active = false;
  }
}
