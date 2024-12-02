import Service from "@ember/service";
import { TrackedSet } from "tracked-built-ins";

/**
 * This service is responsible for rendering glimmer components into HTML generated
 * by raw-hbs. It is not intended to be used directly.
 *
 * See discourse/lib/raw-render-glimmer.js for usage instructions.
 */
export default class RenderGlimmerService extends Service {
  _registrations = new TrackedSet();

  add(info) {
    this._registrations.add(info);
  }

  remove(info) {
    this._registrations.delete(info);
  }

  /**
   * Removes registrations for elements which are no longer in the DOM.
   */
  cleanup() {
    this._registrations.forEach((info) => {
      if (!document.body.contains(info.element)) {
        this.remove(info);
      }
    });
  }
}
