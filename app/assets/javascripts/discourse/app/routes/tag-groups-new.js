import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class TagGroupsNew extends DiscourseRoute {
  @service router;

  beforeModel() {
    if (!this.siteSettings.tagging_enabled) {
      this.router.transitionTo("tagGroups");
    }
  }

  model() {
    return this.store.createRecord("tagGroup", {
      name: i18n("tagging.groups.new_name"),
    });
  }
}
