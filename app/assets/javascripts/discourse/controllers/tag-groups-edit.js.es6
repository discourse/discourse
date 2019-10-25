import { inject } from "@ember/controller";
import Controller from "@ember/controller";
export default Controller.extend({
  tagGroups: inject(),

  actions: {
    save() {
      this.model.save();
    },

    destroy() {
      return bootbox.confirm(
        I18n.t("tagging.groups.confirm_delete"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        destroy => {
          if (destroy) {
            const c = this.get("tagGroups.model");
            return this.model.destroy().then(() => {
              c.removeObject(this.model);
              this.transitionToRoute("tagGroups");
            });
          }
        }
      );
    }
  }
});
