import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { arraySortedByProperties } from "discourse/lib/array-tools";

export default class AdminEmailTemplatesIndexController extends Controller {
  @tracked showOverridenOnly = false;

  titleSorting = ["title"];

  @computed("emailTemplates.content", "titleSorting")
  get sortedTemplates() {
    return arraySortedByProperties(
      this.emailTemplates?.content,
      this.titleSorting
    );
  }

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
