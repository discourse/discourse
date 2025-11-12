import { action } from "@ember/object";
import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { TOAST } from "discourse/float-kit/lib/constants";
import uniqueId from "discourse/helpers/unique-id";

export default class DToastInstance {
  @service site;
  @service toasts;

  options = null;
  id = uniqueId();

  constructor(owner, options = {}) {
    setOwner(this, owner);
    this.options = { ...TOAST.options, ...options };
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
