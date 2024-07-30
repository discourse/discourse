import Controller from "@ember/controller";
import { action } from "@ember/object";
import { sort } from "@ember/object/computed";
import { service } from "@ember/service";

export default class AdminCustomizeEmailTemplatesController extends Controller {
  @service router;

  titleSorting = ["title"];
  @sort("emailTemplates", "titleSorting") sortedTemplates;

  @action
  onSelectTemplate(template) {
    this.router.transitionTo("adminCustomizeEmailTemplates.edit", template);
  }
}
