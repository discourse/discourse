export default Ember.Controller.extend({
  tagGroups: Ember.inject.controller(),

  actions: {
    save() {
      this.get("model").save();
    },

    destroy() {
      return bootbox.confirm(
        I18n.t("tagging.groups.confirm_delete"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        destroy => {
          if (destroy) {
            const c = this.get("tagGroups.model");
            return this.get("model")
              .destroy()
              .then(() => {
                c.removeObject(this.get("model"));
                this.transitionToRoute("tagGroups");
              });
          }
        }
      );
    }
  }
});
