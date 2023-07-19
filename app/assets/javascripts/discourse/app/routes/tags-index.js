import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import Tag from "discourse/models/tag";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default DiscourseRoute.extend({
  router: service(),

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
  },

  titleToken() {
    return I18n.t("tagging.tags");
  },

  setupController(controller, model) {
    this.controllerFor("tags.index").setProperties({
      model,
      sortProperties: this.siteSettings.tags_sort_alphabetically
        ? ["id"]
        : ["totalCount:desc", "id"],
    });
  },

  @action
  didTransition() {
    this.controllerFor("application").set("showFooter", true);
    return true;
  },

  @action
  showTagGroups() {
    this.router.transitionTo("tagGroups");
    return true;
  },

  @action
  triggerRefresh() {
    this.refresh();
  },
});
