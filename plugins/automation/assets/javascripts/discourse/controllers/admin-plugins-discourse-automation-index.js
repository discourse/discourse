import Controller from "@ember/controller";
import I18n from "I18n";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { action } from "@ember/object";
import escape from "discourse-common/lib/escape";
import { inject as service } from "@ember/service";

export default class AutomationIndex extends Controller {
  @service dialog;
  @action
  editAutomation(automation) {
    this.transitionToRoute(
      "adminPlugins.discourse-automation.edit",
      automation.id
    );
  }

  @action
  newAutomation() {
    this.transitionToRoute("adminPlugins.discourse-automation.new");
  }

  @action
  destroyAutomation(automation) {
    this.dialog.deleteConfirm({
      message: I18n.t("discourse_automation.destroy_automation.confirm", {
        name: escape(automation.name),
      }),
      didConfirm: () => {
        return automation
          .destroyRecord()
          .then(() => this.send("triggerRefresh"))
          .catch(popupAjaxError);
      },
    });
  }
}
