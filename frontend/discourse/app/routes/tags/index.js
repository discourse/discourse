import { action } from "@ember/object";
import Tag from "discourse/models/tag";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class TagsIndex extends DiscourseRoute {
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
    const sortProperties = this.siteSettings.tags_sort_alphabetically
      ? ["name"]
      : ["totalCount:desc", "name"];
    controller.setProperties({ model, sortProperties });
  }

  @action
  triggerRefresh() {
    this.refresh();
  }
}
