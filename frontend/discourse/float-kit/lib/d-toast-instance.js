import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { TOAST } from "discourse/float-kit/lib/constants";
import deprecated from "discourse/lib/deprecated";
import dUniqueId from "discourse/ui-kit/helpers/d-unique-id";

export default class DToastInstance {
  @service site;
  @service toasts;

  @tracked dismissed = false;
  @tracked stackOrder = 0;

  options = null;
  id = dUniqueId();

  constructor(owner, options = {}) {
    setOwner(this, owner);
    this.options = { ...TOAST.options, ...options };
  }

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

  @action
  close() {
    this.toasts.close(this);
  }

  get isValidForView() {
    return this.options.views.includes(
      this.site.desktopView ? "desktop" : "mobile"
    );
  }
}
