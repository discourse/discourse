import Route from "@ember/routing/route";
export default Route.extend({
  model() {
    return this.store.findAll("web-hook");
  },

  setupController(controller, model) {
    controller.setProperties({
      model,
      eventTypes: model.extras.event_types,
      defaultEventTypes: model.extras.default_event_types,
      contentTypes: model.extras.content_types,
      deliveryStatuses: model.extras.delivery_statuses
    });
  }
});
