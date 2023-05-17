import I18n from "I18n";
import { dasherize } from "@ember/string";
import { getOwner } from "discourse-common/lib/get-owner";

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
  opts = opts || {};

  let container = getOwner(this);
  if (container.isDestroying || container.isDestroyed) {
    return;
  }

  // We use the container here because modals are like singletons
  // in Discourse. Only one can be shown with a particular state.
  const route = container.lookup("route:application");
  const modalController = route.controllerFor("modal");

  modalController.set(
    "modalClass",
    opts.modalClass || `${dasherize(name).toLowerCase()}-modal`
  );

  const controllerName = opts.admin ? `modals/${name}` : name;
  modalController.set("name", controllerName);

  let controller = container.lookup("controller:" + controllerName);
  const templateName = opts.templateName || dasherize(name);

  const renderArgs = { into: "modal", outlet: "modalBody" };
  if (controller) {
    renderArgs.controller = controllerName;
  } else {
    // use a basic controller
    renderArgs.controller = "basic-modal-body";
    controller = container.lookup(`controller:${renderArgs.controller}`);
  }

  if (opts.addModalBodyView) {
    renderArgs.view = "modal-body";
  }

  const modalName = `modal/${templateName}`;
  const fullName = opts.admin ? `admin/templates/${modalName}` : modalName;
  route.render(fullName, renderArgs);
  if (opts.title) {
    modalController.set("title", I18n.t(opts.title));
  } else if (opts.titleTranslated) {
    modalController.set("title", opts.titleTranslated);
  } else {
    modalController.set("title", null);
  }

  if (opts.titleAriaElementId) {
    modalController.set("titleAriaElementId", opts.titleAriaElementId);
  }

  if (opts.panels) {
    modalController.setProperties({
      panels: opts.panels,
      selectedPanel: opts.panels[0],
    });

    if (controller.actions.onSelectPanel) {
      modalController.set(
        "onSelectPanel",
        controller.actions.onSelectPanel.bind(controller)
      );
    }

    modalController.set(
      "modalClass",
      `${modalController.get("modalClass")} has-tabs`
    );
  } else {
    modalController.setProperties({ panels: [], selectedPanel: null });
  }

  controller.set("modal", modalController);
  const model = opts.model;
  if (model) {
    controller.set("model", model);
  }
  if (controller.onShow) {
    controller.onShow();
  }
  controller.set("flashMessage", null);

  return controller;
}
