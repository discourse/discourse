import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { inject as service } from "@ember/service";

export default class Automation extends Controller {
  @service router;

  @computed("router.currentRouteName")
  get showNewAutomation() {
    return (
      this.router.currentRouteName === "adminPlugins.discourse-automation.index"
    );
  }

  @action
  newAutomation() {
    this.transitionToRoute("adminPlugins.discourse-automation.new");
  }
}
