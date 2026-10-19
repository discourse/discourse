import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";
import { waitForPromise } from "@ember/test-waiters";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { waitForClosedKeyboard } from "discourse/lib/wait-for-keyboard";
import { CLOSE_INITIATED_BY_MODAL_SHOW } from "discourse/ui-kit/d-modal";

const LEGACY_OPTS = new Set([
  "admin",
  "templateName",
  "title",
  "titleTranslated",
  "modalClass",
  "titleAriaElementId",
  "panels",
]);

@disableImplicitInjections
export default class ModalService extends Service {
  @service site;
  @service capabilities;

  @tracked activeModal;
  @tracked opts = {};

  @tracked containerElement;

  /** @type {Element | null} */
  triggerElement = null;

  #pendingRequest = null;
  #loadTrigger = null;

  willDestroy() {
    // Don't resolve `show()` promises here: their callers may already be destroyed.
    this.#pendingRequest = null;
    super.willDestroy(...arguments);
  }

  @action
  setContainerElement(element) {
    this.containerElement = element;
  }

  /**
   * Render a modal
   *
   * When given an import promise, the current modal stays open until the new one has loaded,
   * then `show` is called again with the resolved class.
   *
   * @param {Component | Promise<{ default: Component }>} modal - Component class or a dynamic import promise
   * @param {object} [opts] - options
   * @param {object} [opts.model] - An object passed as the component's `@model` argument
   *
   * @returns {Promise} A promise that resolves when the modal is closed, with any data passed to closeModal
   */
  async show(modal, opts) {
    if (typeof modal?.then === "function") {
      return this.#showWhenLoaded(modal, opts);
    }

    const trigger = this.#loadTrigger ?? document.activeElement;
    this.#loadTrigger = null;

    this.close({ initiatedBy: CLOSE_INITIATED_BY_MODAL_SHOW });

    opts ??= {};
    const unsupportedOpts = Object.keys(opts).filter((key) =>
      LEGACY_OPTS.has(key)
    );
    if (unsupportedOpts.length > 0) {
      throw new Error(
        `${unsupportedOpts.join(
          ", "
        )} are not supported in the component-based modal API. See https://meta.discourse.org/t/268057`
      );
    }

    const request = this.#startRequest();

    waitForClosedKeyboard(this.site, this.capabilities).then(() => {
      if (this.#pendingRequest === request) {
        this.#pendingRequest = null;
        this.opts = opts;
        this.activeModal = {
          component: modal,
          opts,
          resolveShowPromise: request.resolve,
        };
        this.triggerElement = trigger;
      }
    });

    return request.promise;
  }

  close(data) {
    this.#pendingRequest?.resolve(data);
    this.#pendingRequest = null;
    this.activeModal?.resolveShowPromise?.(data);
    this.activeModal = null;
    this.opts = {};
    if (this.triggerElement?.isConnected) {
      this.triggerElement.focus();
    }
    this.triggerElement = null;
  }

  #showWhenLoaded(modulePromise, opts) {
    const trigger = document.activeElement;
    const request = this.#startRequest();

    waitForPromise(modulePromise).then(
      ({ default: modal }) => {
        if (this.#pendingRequest === request) {
          this.#pendingRequest = null;
          this.#loadTrigger = trigger;
          request.resolve(this.show(modal, opts));
        }
      },
      (error) => {
        if (this.#pendingRequest === request) {
          this.#pendingRequest = null;
          request.reject(error);
        }
      }
    );

    return request.promise;
  }

  #startRequest() {
    this.#pendingRequest?.resolve({
      initiatedBy: CLOSE_INITIATED_BY_MODAL_SHOW,
    });

    const request = {};
    request.promise = new Promise((resolve, reject) =>
      Object.assign(request, { resolve, reject })
    );
    this.#pendingRequest = request;
    return request;
  }
}
