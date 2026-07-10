import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { trackedArray } from "@ember/reactive/collections";
import Service from "@ember/service";
import DDefaultToast from "discourse/float-kit/components/d-default-toast";
import type {
  ToastData,
  ToastOptions,
} from "discourse/float-kit/lib/constants";
import DToastInstance from "discourse/float-kit/lib/d-toast-instance";

/** The options accepted by the themed convenience methods, which require `data`. */
type ThemedToastOptions = Partial<ToastOptions> & { data: ToastData };

export default class Toasts extends Service {
  @tracked activeToasts = trackedArray<DToastInstance>();

  /**
   * Render a toast.
   *
   * @param options - options passed to the toast component as its `@toast` argument;
   *   each field is documented on {@link ToastOptions}. When no `component` is given,
   *   `DDefaultToast` is used.
   *
   * @returns the created toast instance.
   */
  @action
  show(options: Partial<ToastOptions> = {}) {
    const instance = new DToastInstance(getOwner(this)!, {
      component: DDefaultToast,
      ...options,
    });

    if (instance.isValidForView) {
      this.activeToasts.push(instance);
    }

    return instance;
  }

  /**
   * Render a `DDefaultToast` with the default theme.
   *
   * @param options - see `show`.
   */
  @action
  default(options: ThemedToastOptions) {
    options.data.theme = "default";

    return this.show(options);
  }

  /**
   * Render a `DDefaultToast` with the success theme.
   *
   * @param options - see `show`.
   */
  @action
  success(options: ThemedToastOptions) {
    options.data.theme = "success";
    options.data.icon ??= "check";

    return this.show(options);
  }

  /**
   * Render a `DDefaultToast` with the error theme.
   *
   * @param options - see `show`.
   */
  @action
  error(options: ThemedToastOptions) {
    options.data.theme = "error";
    options.data.icon ??= "triangle-exclamation";

    return this.show(options);
  }

  /**
   * Render a `DDefaultToast` with the warning theme.
   *
   * @param options - see `show`.
   */
  @action
  warning(options: ThemedToastOptions) {
    options.data.theme = "warning";
    options.data.icon ??= "circle-exclamation";

    return this.show(options);
  }

  /**
   * Render a `DDefaultToast` with the info theme.
   *
   * @param options - see `show`.
   */
  @action
  info(options: ThemedToastOptions) {
    options.data.theme = "info";
    options.data.icon ??= "circle-info";

    return this.show(options);
  }

  /**
   * Close a toast. Any object with a valid `id` property can be used.
   */
  @action
  close(toast: Pick<DToastInstance, "id">) {
    this.activeToasts = trackedArray(
      this.activeToasts.filter((activeToast) => activeToast.id !== toast.id)
    );
  }
}
