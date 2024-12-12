import Route from "@ember/routing/route";

export default class AdminWebHooksIndexRoute extends Route {
  model() {
    return this.store.findAll("web-hook");
  }

  setupController(controller, model) {
    controller.setProperties({
      model,
      groupedEventTypes: model.extras.grouped_event_types,
      defaultEventTypes: model.extras.default_event_types,
      contentTypes: model.extras.content_types,
      deliveryStatuses: model.extras.delivery_statuses,
    });
  }
}
