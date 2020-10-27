import I18n from "I18n";
import DiscourseRoute from "discourse/routes/discourse";
import { SEARCH_PRIORITIES } from "discourse/lib/constants";

export default DiscourseRoute.extend({
  model() {
    const groups = this.site.groups,
      everyoneName = groups.findBy("id", 0).name;

    return this.store.createRecord("category", {
      color: "0088CC",
      text_color: "FFFFFF",
      group_permissions: [{ group_name: everyoneName, permission_type: 1 }],
      available_groups: groups.map((g) => g.name),
      allow_badges: true,
      topic_featured_link_allowed: true,
      custom_fields: {},
      search_priority: SEARCH_PRIORITIES.normal,
    });
  },

  titleToken() {
    return I18n.t("category.create");
  },

  renderTemplate() {
    this.currentModel.params = {
      tab: "general",
    };

    this.render("edit-category-tab", {
      controller: "edit-category-tab",
      model: this.currentModel,
    });
  },
});
