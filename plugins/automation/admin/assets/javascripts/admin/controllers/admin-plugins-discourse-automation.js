import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";

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
    this.router.transitionTo("adminPlugins.discourse-automation.new");
  }
}
