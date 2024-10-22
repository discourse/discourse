import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class AutomationNew extends Controller {
  @service router;

  @tracked filterText = "";

  @action
  updateFilterText(event) {
    this.filterText = event.target.value;
  }

  @action
  resetFilterText() {
    this.filterText = "";
  }

  get scriptableContent() {
    let scripts = this.model.scriptables.content;
    let filter = this.filterText.toLowerCase();

    if (!filter) {
      return scripts;
    }

    return scripts.filter((script) => {
      const name = script.name ? script.name.toLowerCase() : "";
      const description = script.description
        ? script.description.toLowerCase()
        : "";
      return name.includes(filter) || description.includes(filter);
    });
  }

  @action
  selectScriptToEdit(newScript) {
    this.model.automation.save({ script: newScript.id }).then(() => {
      this.router.transitionTo(
        "adminPlugins.discourse-automation.edit",
        this.model.automation.id
      );
    });
  }
}
