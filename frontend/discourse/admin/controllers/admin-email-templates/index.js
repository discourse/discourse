import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import { arraySortedByProperties } from "discourse/lib/array-tools";
import DiscourseURL, { applyQueryParams } from "discourse/lib/url";

export default class AdminEmailTemplatesIndexController extends Controller {
  @service router;

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

    // `overridden` is deliberately not a registered query param, so sync the
    // URL without a transition, preserving the search input's `filter` param
    DiscourseURL.replaceState(
      applyQueryParams(this.router.currentURL, {
        overridden: this.showOverridenOnly && "true",
      })
    );
  }
}
