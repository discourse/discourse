import Route from "@ember/routing/route";
export default Route.extend({
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
    this._shouldAlertUnsavedChanges = true;
  },

  actions: {
    willTransition(transition) {
      if (
        this.get("controller.model.changed") &&
        this._shouldAlertUnsavedChanges &&
        transition.intent.name !== this.routeName
      ) {
        transition.abort();
        bootbox.confirm(
          I18n.t("admin.customize.theme.unsaved_changes_alert"),
          I18n.t("admin.customize.theme.discard"),
          I18n.t("admin.customize.theme.stay"),
          result => {
            if (!result) {
              this._shouldAlertUnsavedChanges = false;
              transition.retry();
            }
          }
        );
      }
    }
  }
});
