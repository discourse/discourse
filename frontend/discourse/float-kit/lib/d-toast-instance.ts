import { action } from "@ember/object";
import Owner, { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { TOAST, type ToastOptions } from "discourse/float-kit/lib/constants";
import type ToastsService from "discourse/float-kit/services/toasts";
import type Site from "discourse/models/site";
import dUniqueId from "discourse/ui-kit/helpers/d-unique-id";

/**
 * The instance backing a single toast: its merged options and a stable id used
 * to track and dismiss it. Unlike a menu or tooltip a toast has no trigger — it
 * is shown imperatively through the `toasts` service — so this does not extend
 * `FloatKitInstance`.
 */
export default class DToastInstance {
  @service declare site: Site;
  @service declare toasts: ToastsService;

  options: ToastOptions;
  id = dUniqueId();

  constructor(owner: Owner, options: Partial<ToastOptions> = {}) {
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
