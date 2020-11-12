import I18n from "I18n";
import DiscourseRoute from "discourse/routes/discourse";
import { SEARCH_PRIORITIES } from "discourse/lib/constants";
import { Promise } from "rsvp";

export default DiscourseRoute.extend({
  model() {
    return Promise.resolve(this.defaultGroupPermissions()).then(
      (permissions) => {
        return this.store.createRecord("category", {
          color: "0088CC",
          text_color: "FFFFFF",
          group_permissions: permissions,
          available_groups: this.site.groups.map((g) => g.name),
          allow_badges: true,
          topic_featured_link_allowed: true,
          custom_fields: {},
          search_priority: SEARCH_PRIORITIES.normal,
        });
      }
    );
  },

  titleToken() {
    return I18n.t("category.create");
  },

  defaultGroupPermissions() {
    return [
      {
        group_name: this.site.groups.findBy("id", 0).name,
        permission_type: 1,
      },
    ];
  },

  renderTemplate() {
    this.render("edit-category-tabs", {
      controller: "edit-category-tabs",
      model: this.currentModel,
    });
  },
});
