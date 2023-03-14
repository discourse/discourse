import { sort } from "@ember/object/computed";
import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class AdminCustomizeEmailTemplatesController extends Controller {
  @sort("emailTemplates", "titleSorting") sortedTemplates;

  init() {
    super.init(...arguments);

    this.set("titleSorting", ["title"]);
  }

  @action
  onSelectTemplate(template) {
    this.transitionToRoute("adminCustomizeEmailTemplates.edit", template);
  }
}
