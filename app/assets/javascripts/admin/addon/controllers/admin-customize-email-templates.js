import { sort } from "@ember/object/computed";
import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class AdminCustomizeEmailTemplatesController extends Controller {
  titleSorting = ["title"];
  @sort("emailTemplates", "titleSorting") sortedTemplates;

  @action
  onSelectTemplate(template) {
    this.transitionToRoute("adminCustomizeEmailTemplates.edit", template);
  }
}
