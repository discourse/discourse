import { setOwner } from "@ember/application";
import { action } from "@ember/object";
import { service } from "@ember/service";
import uniqueId from "discourse/helpers/unique-id";
import { TOAST } from "float-kit/lib/constants";

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
