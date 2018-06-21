export default Ember.Route.extend({
  model(params) {
    const all = this.modelFor("adminCustomizeThemes");
    const model = all.findBy("id", parseInt(params.theme_id));
    return model
      ? {
          model,
          target: params.target,
          field_name: params.field_name
        }
      : this.replaceWith("adminCustomizeThemes.index");
  },

  serialize(wrapper) {
    return {
      model: wrapper.model,
      target: wrapper.target || "common",
      field_name: wrapper.field_name || "scss",
      theme_id: wrapper.model.get("id")
    };
  },

  setupController(controller, wrapper) {
    const fields = controller.fieldsForTarget(wrapper.target);
    if (!fields.includes(wrapper.field_name)) {
      this.transitionTo(
        "adminCustomizeThemes.edit",
        wrapper.model.id,
        wrapper.target,
        fields[0]
      );
      return;
    }
    controller.set("model", wrapper.model);
    controller.setTargetName(wrapper.target || "common");
    controller.set("fieldName", wrapper.field_name || "scss");
    this.controllerFor("adminCustomizeThemes").set("editingTheme", true);
  }
});
