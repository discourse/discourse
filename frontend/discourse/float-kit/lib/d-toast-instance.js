import { action } from "@ember/object";
import { setOwner } from "@ember/owner";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { TOAST } from "discourse/float-kit/lib/constants";
import deprecated from "discourse/lib/deprecated";
import uniqueId from "discourse/helpers/unique-id";

/**
 * Represents an individual toast instance with its state and configuration.
 */
export default class DToastInstance {
  @service site;
  @service toasts;

  @tracked dismissed = false;
  @tracked stackOrder = 0;

  options = null;
  id = uniqueId();

  constructor(owner, options = {}) {
    setOwner(this, owner);
    this.options = { ...TOAST.options, ...options };
  }

  /**
   * The normalized duration in milliseconds.
   * Supports 'short', 'long', or a custom integer value (deprecated).
   *
   * @returns {number}
   */
  get duration() {
    const { duration } = this.options;

    if (duration === "long") {
      return 5000;
    } else if (duration === "short") {
      return 3000;
    } else if (Number.isInteger(duration)) {
      deprecated(
        "Using an integer for the duration property of the d-toast component is deprecated. Use `short` or `long` instead.",
        { id: "float-kit.d-toast.duration" }
      );
      return duration;
    }

    return 3000;
  }

  /**
   * Closes the toast by removing it from the active toasts list.
   */
  @action
  close() {
    this.toasts.close(this);
  }

  /**
   * Whether the toast should be displayed on the current view (desktop/mobile).
   *
   * @returns {boolean}
   */
  get isValidForView() {
    return this.options.views.includes(
      this.site.desktopView ? "desktop" : "mobile"
    );
  }
}
