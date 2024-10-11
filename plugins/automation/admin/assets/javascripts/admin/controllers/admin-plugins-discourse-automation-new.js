import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { UNNAMED_AUTOMATION_PLACEHOLDER } from "../utils/automation-placeholder";

export default class AutomationNew extends Controller {
  @service router;

  @tracked filterText = "";

  @action
  updateFilterText(event) {
    this.filterText = event.target.value;
  }

  get scriptableContent() {
    let scripts = this.model.scriptables.content;
    let filter = this.filterText.toLowerCase();

    if (!filter) {
      return scripts;
    }

    return scripts.filter((script) => {
      return (
        script.name.toLowerCase().includes(filter) ||
        script.description.toLowerCase().includes(filter)
      );
    });
  }

  @action
  selectScriptToEdit(newScript) {
    this.model.automation
      .save({ name: UNNAMED_AUTOMATION_PLACEHOLDER, script: newScript.id })
      .then(() => {
        this.router.transitionTo(
          "adminPlugins.discourse-automation.edit",
          this.model.automation.id
        );
      });
  }
}
