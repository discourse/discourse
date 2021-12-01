import I18n from "I18n";
import bootbox from "bootbox";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { action } from "@ember/object";

export default Ember.Controller.extend({
  @action
  editAutomation(automation) {
    this.transitionToRoute(
      "adminPlugins.discourse-automation.edit",
      automation.id
    );
  },

  @action
  destroyAutomation(automation) {
    bootbox.confirm(
      I18n.t("discourse_automation.destroy_automation.confirm", {
        name: automation.name,
      }),
      (result) => {
        if (result) {
          automation
            .destroyRecord()
            .then(() => this.send("triggerRefresh"))
            .catch(popupAjaxError);
        }
      }
    );
  },
});
