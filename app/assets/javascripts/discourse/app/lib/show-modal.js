// Remove when legacy modals are dropped (deprecation: discourse.modal-controllers)

import { getOwnerWithFallback } from "discourse/lib/get-owner";

/**
 * Render a modal
 *
 * @param {string} name - the controller/template name for the modal body.
 *
 * @param {Object} [options] - options
 * @param {string} [options.model] - An object which will be set as the `model` property on the controller
 * @param {boolean} [options.admin] - look under the admin namespace for the controller/template
 * @param {string} [options.templateName] - override the template name to render
 * @param {string} [options.title] - (deprecated) translation key for modal title. Pass `@title` to DModalBody instead
 * @param {string} [options.titleTranslated] - (deprecated) translated modal title. Pass `@rawTitle` to DModalBody instead
 * @param {string} [options.modalClass] - (deprecated) classname for modal. Pass `@modalClass` to DModalBody instead
 * @param {string} [options.titleAriaElementId] - (deprecated) Pass `@titleAriaElementId` to DModalBody instead
 *
 * @returns {Controller} The modal controller instance
 */
export default function showModal(name, opts) {
  if (typeof name !== "string") {
    throw new Error(
      "`discourse/lib/show-modal` can only be used with the legacy controller-based API. To use the new component-based API, inject the modal service and call modal.show(). https://meta.discourse.org/t/268057"
    );
  }
  opts = opts || {};

  let container = getOwnerWithFallback(this);
  if (container.isDestroying || container.isDestroyed) {
    return;
  }

  const modalService = container.lookup("service:modal");
  return modalService.show(name, opts);
}
