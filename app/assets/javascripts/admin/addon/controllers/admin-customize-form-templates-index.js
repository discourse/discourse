import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class AdminCustomizeFormTemplatesIndex extends Controller {
  @action
  newTemplate() {
    this.transitionToRoute("adminCustomizeFormTemplates.new");
  }
}
