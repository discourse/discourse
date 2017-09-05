export default function(name, opts) {
  opts = opts || {};
  const container = Discourse.__container__;

  // We use the container here because modals are like singletons
  // in Discourse. Only one can be shown with a particular state.
  const route = container.lookup('route:application');
  const modalController = route.controllerFor('modal');

  modalController.set('modalClass', opts.modalClass);

  const controllerName = opts.admin ? `modals/${name}` : name;

  let controller = container.lookup('controller:' + controllerName);
  const templateName = opts.templateName || Ember.String.dasherize(name);

  const renderArgs = { into: 'modal', outlet: 'modalBody'};
  if (controller) {
    renderArgs.controller = controllerName;
  } else {
    // use a basic controller
    renderArgs.controller = 'basic-modal-body';
    controller = container.lookup(`controller:${renderArgs.controller}`);
  }


  if (opts.addModalBodyView) {
    renderArgs.view = 'modal-body';
  }

  const modalName = `modal/${templateName}`;
  const fullName = opts.admin ? `admin/templates/${modalName}` : modalName;
  route.render(fullName, renderArgs);
  if (opts.title) {
    modalController.set('title', I18n.t(opts.title));
  }

  controller.set('modal', modalController);
  const model = opts.model;
  if (model) { controller.set('model', model); }
  if (controller.onShow) { controller.onShow(); }
  controller.set('flashMessage', null);

  return controller;
};
