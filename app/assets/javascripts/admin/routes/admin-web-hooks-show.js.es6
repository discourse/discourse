export default Discourse.Route.extend({
  serialize(model) {
    return { web_hook_id: model.id || "new" };
  },

  model(params) {
    if (params.web_hook_id === "new") {
      return this.store.createRecord("web-hook");
    }
    return this.store.find("web-hook", Ember.get(params, "web_hook_id"));
  },

  setupController(controller, model) {
    if (
      model.isNew ||
      Ember.isEmpty(model.web_hook_event_types)
    ) {
      model.set("web_hook_event_types", controller.defaultEventTypes);
    }

    model.set("category_ids", model.category_ids);
    model.set("tag_names", model.tag_names);
    model.set("group_ids", model.group_ids);
    controller.setProperties({ model, saved: false });
  },

  renderTemplate() {
    this.render("admin/templates/web-hooks-show", { into: "adminApi" });
  }
});
