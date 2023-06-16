import Service, { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/application";
import I18n from "I18n";
import { dasherize } from "@ember/string";
import { action } from "@ember/object";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

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
class ModalService extends Service {
  @tracked modalBodyComponent;
  @tracked opts = {};
  @tracked containerElement;

  @action
  setContainerElement(element) {
    this.containerElement = element;
  }

  show(modal, opts) {
    this.opts = opts || {};
    this.modalBodyComponent = modal;

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
  }

  close() {
    this.modalBodyComponent = null;
    this.opts = {};
  }
}

// Remove all logic below when legacy modals are dropped (deprecation: discourse.modal-controllers)
export default class ModalServiceWithLegacySupport extends ModalService {
  @service appEvents;

  @tracked name;
  @tracked selectedPanel;
  @tracked hidden = true;

  @tracked titleOverride;
  @tracked modalClassOverride;
  @tracked onSelectPanel;

  get title() {
    if (this.titleOverride) {
      return this.titleOverride;
    } else if (this.opts.titleTranslated) {
      return this.opts.titleTranslated;
    } else if (this.opts.title) {
      return I18n.t(this.opts.title);
    } else {
      return null;
    }
  }

  set title(value) {
    this.titleOverride = value;
  }

  get modalClass() {
    if (!this.isLegacy) {
      return null;
    }

    return (
      this.modalClassOverride ||
      this.opts.modalClass ||
      `${dasherize(this.name.replace(/^modals\//, "")).toLowerCase()}-modal`
    );
  }

  set modalClass(value) {
    this.modalClassOverride = value;
  }

  show(modal, opts = {}) {
    if (typeof modal !== "string") {
      return super.show(modal, opts);
    }

    const name = modal;
    const container = getOwner(this);
    const route = container.lookup("route:application");

    this.opts = opts;

    const controllerName = opts.admin ? `modals/${name}` : name;
    this.name = controllerName;

    let controller = container.lookup("controller:" + controllerName);
    const templateName = opts.templateName || dasherize(name);

    const renderArgs = { into: "application", outlet: "modalBody" };
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

    if (opts.panels) {
      if (controller.actions.onSelectPanel) {
        this.onSelectPanel = controller.actions.onSelectPanel.bind(controller);
      }
      this.selectedPanel = opts.panels[0];
    }

    controller.set("modal", this);
    const model = opts.model;
    if (model) {
      controller.set("model", model);
    }
    if (controller.onShow) {
      controller.onShow();
    }
    controller.set("flashMessage", null);

    return (this.activeController = controller);
  }

  close(initiatedBy) {
    const controllerName = this.name;
    const controller = controllerName
      ? getOwner(this).lookup(`controller:${controllerName}`)
      : null;

    if (controller?.beforeClose?.() === false) {
      return;
    }

    getOwner(this)
      .lookup("route:application")
      .render("hide-modal", { into: "application", outlet: "modalBody" });
    $(".d-modal.fixed-modal").modal("hide");

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
    this.hidden = true;

    this.name =
      this.selectedPanel =
      this.modalClassOverride =
      this.titleOverride =
      this.onSelectPanel =
        null;

    super.close();
  }

  hide() {
    if (this.isLegacy) {
      $(".d-modal.fixed-modal").modal("hide");
    } else {
      throw "hide/reopen are not supported for component-based modals";
    }
  }

  reopen() {
    if (this.isLegacy) {
      $(".d-modal.fixed-modal").modal("show");
    } else {
      throw "hide/reopen are not supported for component-based modals";
    }
  }

  get isLegacy() {
    return this.name && !this.modalBodyComponent;
  }
}
