import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import Service from "@ember/service";
import { TrackedArray } from "tracked-built-ins";
import DDefaultToast from "float-kit/components/d-default-toast";
import DToastInstance from "float-kit/lib/d-toast-instance";

export default class Toasts extends Service {
  @tracked activeToasts = new TrackedArray();

  /**
   * Render a toast
   *
   * @param {Object} [options] - options passed to the toast component as `@toast` argument
   * @param {String} [options.duration] - The duration (ms) of the toast, will be closed after this time
   * @param {Boolean} [options.autoClose=true] - When true, the toast will autoClose after the duration
   * @param {ComponentClass} [options.component] - A component to render, will use `DDefaultToast` if not provided
   * @param {String} [options.class] - A class added to the d-toast element
   * @param {Object} [options.data] - An object which will be passed as the `@data` argument to the component
   *
   * @returns {DToastInstance} - a toast instance
   */
  @action
  show(options = {}) {
    const instance = new DToastInstance(getOwner(this), {
      component: DDefaultToast,
      ...options,
    });

    if (instance.isValidForView) {
      this.activeToasts.push(instance);
    }

    return instance;
  }

  /**
   * Render a DDefaultToast toast with the default theme
   *
   * @param {Object} [options] - @see show
   *
   * @returns {DToastInstance} - a toast instance
   */
  @action
  default(options = {}) {
    options.data.theme = "default";

    return this.show(options);
  }

  /**
   * Render a DDefaultToast toast with the success theme
   *
   * @param {Object} [options] - @see show
   *
   * @returns {DToastInstance} - a toast instance
   */
  @action
  success(options = {}) {
    options.data.theme = "success";
    options.data.icon ??= "check";

    return this.show(options);
  }

  /**
   * Render a DDefaultToast toast with the error theme
   *
   * @param {Object} [options] - @see show
   *
   * @returns {DToastInstance} - a toast instance
   */
  @action
  error(options = {}) {
    options.data.theme = "error";
    options.data.icon ??= "triangle-exclamation";

    return this.show(options);
  }

  /**
   * Render a DDefaultToast toast with the warning theme
   *
   * @param {Object} [options] - @see show
   *
   * @returns {DToastInstance} - a toast instance
   */
  @action
  warning(options = {}) {
    options.data.theme = "warning";
    options.data.icon ??= "circle-exclamation";

    return this.show(options);
  }

  /**
   * Render a DDefaultToast toast with the info theme
   *
   * @param {Object} [options] - @see show
   *
   * @returns {DToastInstance} - a toast instance
   */
  @action
  info(options = {}) {
    options.data.theme = "info";
    options.data.icon ??= "circle-info";

    return this.show(options);
  }

  /**
   * Close a toast. Any object containing a valid `id` property can be used as a toast parameter.
   */
  @action
  close(toast) {
    this.activeToasts = new TrackedArray(
      this.activeToasts.filter((activeToast) => activeToast.id !== toast.id)
    );
  }
}
