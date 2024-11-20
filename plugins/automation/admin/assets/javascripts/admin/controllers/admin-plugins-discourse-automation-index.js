import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import escape from "discourse-common/lib/escape";
import { i18n } from 'discourse-i18n';

export default class AutomationIndex extends Controller {
  @service dialog;
  @service router;

  @action
  editAutomation(automation) {
    this.router.transitionTo(
      "adminPlugins.discourse-automation.edit",
      automation.id
    );
  }

  @action
  newAutomation() {
    this.router.transitionTo("adminPlugins.discourse-automation.new");
  }

  @action
  destroyAutomation(automation) {
    this.dialog.deleteConfirm({
      message: i18n("discourse_automation.destroy_automation.confirm", {
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
