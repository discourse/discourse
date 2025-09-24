import { action } from "@ember/object";
import { service } from "@ember/service";
import Tag from "discourse/models/tag";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class TagsIndex extends DiscourseRoute {
  @service router;

  model() {
    return this.store.findAll("tag").then((result) => {
      if (result.extras) {
        if (result.extras.categories) {
          result.extras.categories.forEach((category) => {
            category.tags = category.tags.map((t) => Tag.create(t));
          });
        }
        if (result.extras.tag_groups) {
          result.extras.tag_groups.forEach((tagGroup) => {
            tagGroup.tags = tagGroup.tags.map((t) => Tag.create(t));
          });
        }
      }
      return result;
    });
  }

  titleToken() {
    return i18n("tagging.tags");
  }

  setupController(controller, model) {
    this.controllerFor("tags.index").setProperties({
      model,
      sortProperties: this.siteSettings.tags_sort_alphabetically
        ? ["id"]
        : ["totalCount:desc", "id"],
    });
  }

  @action
  showTagGroups() {
    this.router.transitionTo("tagGroups");
    return true;
  }

  @action
  triggerRefresh() {
    this.refresh();
  }
}
