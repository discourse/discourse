import Service, { inject as service } from "@ember/service";
import { getOwner } from "@ember/application";
import I18n from "I18n";
import { dasherize } from "@ember/string";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

@disableImplicitInjections
export default class ModalService extends Service {
  @service appEvents;

  show(name, opts = {}) {
    const container = getOwner(this);
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

  close(initiatedBy) {
    const route = getOwner(this).lookup("route:application");
    let modalController = route.controllerFor("modal");
    const controllerName = modalController.get("name");

    if (controllerName) {
      const controller = getOwner(this).lookup(`controller:${controllerName}`);
      if (controller && controller.beforeClose) {
        if (false === controller.beforeClose()) {
          return;
        }
      }
    }

    getOwner(this)
      .lookup("route:application")
      .render("hide-modal", { into: "modal", outlet: "modalBody" });
    $(".d-modal.fixed-modal").modal("hide");

    if (controllerName) {
      const controller = getOwner(this).lookup(`controller:${controllerName}`);

      if (controller) {
        this.appEvents.trigger("modal:closed", {
          name: controllerName,
          controller,
        });

        if (controller.onClose) {
          controller.onClose({
            initiatedByCloseButton: initiatedBy === "initiatedByCloseButton",
            initiatedByClickOut: initiatedBy === "initiatedByClickOut",
            initiatedByESC: initiatedBy === "initiatedByESC",
          });
        }
      }
      modalController.set("name", null);
    }
    modalController.hidden = true;
  }

  hide() {
    $(".d-modal.fixed-modal").modal("hide");
  }

  reopen() {
    $(".d-modal.fixed-modal").modal("show");
  }
}
