import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { sort } from "@ember/object/computed";

export default class AdminEmailTemplatesIndexController extends Controller {
  @tracked showOverridenOnly = false;

  titleSorting = ["title"];
  @sort("emailTemplates.content", "titleSorting") sortedTemplates;

  get shownTemplates() {
    if (this.showOverridenOnly) {
      return this.sortedTemplates.filter((template) => template.can_revert);
    } else {
      return this.sortedTemplates;
    }
  }

  @action
  toggleOverridenOnly() {
    this.showOverridenOnly = !this.showOverridenOnly;
  }
}
