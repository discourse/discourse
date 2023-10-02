import Controller from "@ember/controller";
import { inject as service } from "@ember/service";
import { action, computed } from "@ember/object";

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
