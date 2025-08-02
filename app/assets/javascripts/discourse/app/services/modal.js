import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";
import { CLOSE_INITIATED_BY_MODAL_SHOW } from "discourse/components/d-modal";
import { clearAllBodyScrollLocks } from "discourse/lib/body-scroll-lock";
import deprecated from "discourse/lib/deprecated";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { waitForClosedKeyboard } from "discourse/lib/wait-for-keyboard";

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
  @service dialog;

  @tracked activeModal;
  @tracked opts = {};

  @tracked containerElement;

  triggerElement = null;

  @action
  setContainerElement(element) {
    this.containerElement = element;
  }

  /**
   * Render a modal
   *
   * @param {Component} modal - a reference to the component class for the modal
   * @param {Object} [options] - options
   * @param {string} [options.model] - An object which will be passed as the `@model` argument on the component
   *
   * @returns {Promise} A promise that resolves when the modal is closed, with any data passed to closeModal
   */
  async show(modal, opts) {
    if (typeof modal === "string") {
      this.dialog.alert(
        `Error: the '${modal}' modal needs updating to work with the latest version of Discourse. See https://meta.discourse.org/t/268057.`
      );
      deprecated(
        `Defining modals using a controller is no longer supported. Use the component-based API instead. (modal: ${modal})`,
        {
          id: "discourse.modal-controllers",
          since: "3.1",
          dropFrom: "3.2",
          url: "https://meta.discourse.org/t/268057",
          raiseError: true,
        }
      );
      return;
    }

    this.close({ initiatedBy: CLOSE_INITIATED_BY_MODAL_SHOW });

    await waitForClosedKeyboard(this);

    let resolveShowPromise;
    const promise = new Promise((resolve) => {
      resolveShowPromise = resolve;
    });

    this.opts = opts ??= {};
    this.activeModal = { component: modal, opts, resolveShowPromise };
    this.triggerElement = document.activeElement;

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

    return promise;
  }

  close(data) {
    clearAllBodyScrollLocks();
    this.activeModal?.resolveShowPromise?.(data);
    this.activeModal = null;
    this.opts = {};
    if (this.triggerElement) {
      this.triggerElement.focus();
      this.triggerElement = null;
    }
  }
}
