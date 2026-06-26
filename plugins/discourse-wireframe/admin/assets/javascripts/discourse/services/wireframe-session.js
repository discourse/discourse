// @ts-check

import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";

/**
 * Holds the editor session's "is the editor open" signal. Entering the editor
 * raises it and exiting lowers it; the many surfaces that show only while
 * editing (the shell, the entry pill, block chrome, the file-drag guard, …)
 * read `active` to gate themselves.
 *
 * It exists as its own peer service rather than living on the kernel because
 * concerns that are themselves services (e.g. image-upload's window-level
 * file-drag guard) need to read it, and reaching back into the kernel for it
 * would form a cycle. A standalone signal everyone reads downward keeps the
 * graph acyclic. It depends on nothing.
 */
export default class WireframeSessionService extends Service {
  // The session flag. `_`-prefixed because `@tracked` can't decorate a `#`
  // field and it's read only through the `active` getter — never written from
  // outside `activate` / `deactivate`.
  @tracked _active = false;

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
