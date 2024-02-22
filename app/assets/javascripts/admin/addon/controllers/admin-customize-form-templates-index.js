import Controller from "@ember/controller";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class AdminCustomizeFormTemplatesIndex extends Controller {
  @service router;

  @action
  newTemplate() {
    this.router.transitionTo("adminCustomizeFormTemplates.new");
  }

  @action
  reload() {
    this.send("reloadModel");
  }
}
