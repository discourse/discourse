import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";
import { CLOSE_INITIATED_BY_MODAL_SHOW } from "discourse/components/d-modal";
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
  @service site;
  @service capabilities;

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
    const trigger = document.activeElement;

    this.close({ initiatedBy: CLOSE_INITIATED_BY_MODAL_SHOW });

    await waitForClosedKeyboard(this.site, this.capabilities);

    let resolveShowPromise;
    const promise = new Promise((resolve) => {
      resolveShowPromise = resolve;
    });

    this.opts = opts ??= {};
    this.activeModal = { component: modal, opts, resolveShowPromise };
    this.triggerElement = trigger;

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
    this.activeModal?.resolveShowPromise?.(data);
    this.activeModal = null;
    this.opts = {};
    if (this.triggerElement?.isConnected) {
      this.triggerElement.focus();
    }
    this.triggerElement = null;
  }
}
