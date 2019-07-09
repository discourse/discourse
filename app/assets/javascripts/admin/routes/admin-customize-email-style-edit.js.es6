export default Ember.Route.extend({
  model(params) {
    return {
      model: this.modelFor("adminCustomizeEmailStyle"),
      fieldName: params.field_name
    };
  },

  setupController(controller, model) {
    controller.setProperties({
      fieldName: model.fieldName,
      model: model.model
    });
    this.set("shouldAlertUnsavedChanges", true);
  },

  actions: {
    willTransition(transition) {
      if (
        this.get("controller.model.changed") &&
        this.shouldAlertUnsavedChanges &&
        transition.intent.name !== this.routeName
      ) {
        transition.abort();
        bootbox.confirm(
          I18n.t("admin.customize.theme.unsaved_changes_alert"),
          I18n.t("admin.customize.theme.discard"),
          I18n.t("admin.customize.theme.stay"),
          result => {
            if (!result) {
              this.set("shouldAlertUnsavedChanges", false);
              transition.retry();
            }
          }
        );
      }
    }
  }
});
