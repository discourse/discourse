import Service, { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/application";
import I18n from "I18n";
import { dasherize } from "@ember/string";
import { action } from "@ember/object";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { CLOSE_INITIATED_BY_MODAL_SHOW } from "discourse/components/d-modal";
import deprecated from "discourse-common/lib/deprecated";

// Known legacy modals in core. Silence deprecation warnings for these so the messages
// don't cause unnecessary noise.
const KNOWN_LEGACY_MODALS = [
  "associate-account-confirm",
  "auth-token",
  "avatar-selector",
  "bulk-change-category",
  "bulk-notification-level",
  "bulk-progress",
  "change-owner",
  "change-post-notice",
  "create-account",
  "create-invite-bulk",
  "create-invite",
  "edit-topic-timer",
  "edit-user-directory-columns",
  "explain-reviewable",
  "feature-topic-on-profile",
  "feature-topic",
  "flag",
  "grant-badge",
  "group-default-notifications",
  "history",
  "ignore-duration-with-username",
  "ignore-duration",
  "login",
  "move-to-topic",
  "post-enqueued",
  "publish-page",
  "raw-email",
  "reject-reason-reviewable",
  "reorder-categories",
  "request-group-membership-form",
  "share-and-invite",
  "tag-upload",
  "topic-summary",
  "user-status",
  "admin-reseed",
  "admin-theme-item",
  "admin-color-scheme-select-base",
  "admin-form-template-validation-options",
  "admin-staff-action-log-details",
  "admin-uploaded-image-list",
];

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
  @tracked activeModal;
  @tracked opts = {};

  @tracked containerElement;

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
  show(modal, opts) {
    this.close({ initiatedBy: CLOSE_INITIATED_BY_MODAL_SHOW });

    let resolveShowPromise;
    const promise = new Promise((resolve) => {
      resolveShowPromise = resolve;
    });

    this.opts = opts || {};
    this.activeModal = { component: modal, opts, resolveShowPromise };

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

    this.close({ initiatedBy: CLOSE_INITIATED_BY_MODAL_SHOW });

    if (!KNOWN_LEGACY_MODALS.includes(modal)) {
      deprecated(
        `Defining modals using a controller is deprecated. Use the component-based API instead. (modal: ${modal})`,
        {
          id: "discourse.modal-controllers",
          since: "3.1",
          dropFrom: "3.2",
          url: "https://meta.discourse.org/t/268057",
        }
      );
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
    if (!this.isLegacy) {
      super.close(...arguments);
    }

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
    return this.name && !this.activeModal;
  }
}
