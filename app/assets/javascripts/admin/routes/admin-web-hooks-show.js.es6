export default Discourse.Route.extend({
  serialize(model) {
    return { web_hook_id: model.get("id") || "new" };
  },

  model(params) {
    if (params.web_hook_id === "new") {
      return this.store.createRecord("web-hook");
    }
    return this.store.find("web-hook", Ember.get(params, "web_hook_id"));
  },

  setupController(controller, model) {
    if (
      model.get("isNew") ||
      Ember.isEmpty(model.get("web_hook_event_types"))
    ) {
      model.set("web_hook_event_types", controller.get("defaultEventTypes"));
    }

    model.set("category_ids", model.get("category_ids"));
    model.set("tag_names", model.get("tag_names"));
    model.set("group_ids", model.get("group_ids"));
    controller.setProperties({ model, saved: false });
  },

  renderTemplate() {
    this.render("admin/templates/web-hooks-show", { into: "adminApi" });
  }
});
