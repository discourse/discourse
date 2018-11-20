import { isAppleDevice } from "discourse/lib/utilities";

export default function(name, opts) {
  opts = opts || {};
  const container = Discourse.__container__;

  // iOS 11 -> 11.1 have broken INPUTs on position fixed
  // if for any reason there is a body higher than 100% behind them.
  // What happens is that when INPUTs gets focus they shift the body
  // which ends up moving the cursor to an invisible spot
  // this makes the login experience on iOS painful, user thinks it is broken.
  //
  // Also, very little value in showing main outlet and header on iOS
  // anyway, so just hide it.
  if (isAppleDevice()) {
    let pos = $(window).scrollTop();
    $(window)
      .off("show.bs.modal.ios-hacks")
      .on("show.bs.modal.ios-hacks", () => {
        $("#main-outlet, header").hide();
      });

    $(window)
      .off("hide.bs.modal.ios-hacks")
      .on("hide.bs.modal.ios-hacks", () => {
        $("#main-outlet, header").show();
        $(window).scrollTop(pos);

        $(window).off("hide.bs.modal.ios-hacks");
        $(window).off("show.bs.modal.ios-hacks");
      });
  }

  // We use the container here because modals are like singletons
  // in Discourse. Only one can be shown with a particular state.
  const route = container.lookup("route:application");
  const modalController = route.controllerFor("modal");

  modalController.set("modalClass", opts.modalClass);

  const controllerName = opts.admin ? `modals/${name}` : name;
  modalController.set("name", controllerName);

  let controller = container.lookup("controller:" + controllerName);
  const templateName = opts.templateName || Ember.String.dasherize(name);

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
