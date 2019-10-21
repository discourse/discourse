import DiscourseRoute from "discourse/routes/discourse";
import Tag from "discourse/models/tag";

export default DiscourseRoute.extend({
  model() {
    return this.store.findAll("tag").then(result => {
      if (result.extras) {
        if (result.extras.categories) {
          result.extras.categories.forEach(category => {
            category.tags = category.tags.map(t => Tag.create(t));
          });
        }
        if (result.extras.tag_groups) {
          result.extras.tag_groups.forEach(tagGroup => {
            tagGroup.tags = tagGroup.tags.map(t => Tag.create(t));
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
        : ["totalCount:desc", "id"]
    });
  },

  actions: {
    didTransition() {
      this.controllerFor("application").set("showFooter", true);
      return true;
    },

    showTagGroups() {
      this.transitionTo("tagGroups");
      return true;
    },

    refresh() {
      this.refresh();
    }
  }
});
