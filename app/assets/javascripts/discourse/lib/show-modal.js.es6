export default (name, model) => {
  // We use the container here because modals are like singletons
  // in Discourse. Only one can be shown with a particular state.
  const route = Discourse.__container__.lookup('route:application');

  route.controllerFor('modal').set('modalClass', null);
  route.render(name, { into: 'modal', outlet: 'modalBody' });

  const controller = route.controllerFor(name);
  if (controller) {
    if (model) { controller.set('model', model); }
    if (controller.onShow) { controller.onShow(); }
    controller.set('flashMessage', null);
  }
};
