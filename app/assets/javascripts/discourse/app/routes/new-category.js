import { service } from "@ember/service";
import { Promise } from "rsvp";
import { SEARCH_PRIORITIES } from "discourse/lib/constants";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

let _newCategoryColor = "0088CC";
let _newCategoryTextColor = "FFFFFF";

export function setNewCategoryDefaultColors(backgroundColor, textColor) {
  _newCategoryColor = backgroundColor;
  _newCategoryTextColor = textColor;
}

export default class NewCategory extends DiscourseRoute {
  @service router;

  controllerName = "edit-category-tabs";

  templateName = "edit-category-tabs";

  beforeModel() {
    if (!this.currentUser) {
      this.router.replaceWith("/404");
      return;
    }
    if (!this.currentUser.admin) {
      if (
        !this.currentUser.moderator ||
        this.siteSettings.moderators_manage_categories_and_groups === false
      ) {
        this.router.replaceWith("/404");
      }
    }
  }

  model() {
    return Promise.resolve(this.groupPermissions())
      .then((permissions) => {
        return this.newCategoryWithPermissions(permissions);
      })
      .catch(() => {
        return this.newCategoryWithPermissions(this.defaultGroupPermissions());
      });
  }

  newCategoryWithPermissions(group_permissions) {
    return this.store.createRecord("category", {
      color: _newCategoryColor,
      text_color: _newCategoryTextColor,
      group_permissions,
      available_groups: this.site.groups.map((g) => g.name),
      allow_badges: true,
      topic_featured_link_allowed: true,
      custom_fields: {},
      category_setting: {},
      search_priority: SEARCH_PRIORITIES.normal,
      required_tag_groups: [],
      form_template_ids: [],
      minimum_required_tags: 0,
    });
  }

  titleToken() {
    return i18n("category.create");
  }

  groupPermissions() {
    // Override this function if you want different groupPermissions from a plugin.
    // If your plugin override fails, permissions will fallback to defaultGroupPermissions
    return this.defaultGroupPermissions();
  }

  defaultGroupPermissions() {
    return [
      {
        group_name: this.site.groups.findBy("id", 0).name,
        permission_type: 1,
      },
    ];
  }
}
