import { service } from "@ember/service";
import { Promise } from "rsvp";
import { SEARCH_PRIORITIES } from "discourse/lib/constants";
import { applyValueTransformer } from "discourse/lib/transformer";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

function getNewCategoryDefaultColors() {
  return applyValueTransformer("category-default-colors", {
    backgroundColor: "0088CC",
    textColor: "FFFFFF",
  });
}

export default class NewCategory extends DiscourseRoute {
  @service router;

  controllerName = "edit-category.tabs";

  templateName = "edit-category.tabs";

  beforeModel() {
    if (!this.currentUser) {
      this.router.replaceWith("/404");
      return;
    }
    if (!this.currentUser.admin) {
      if (
        !this.currentUser.moderator ||
        this.siteSettings.moderators_manage_categories === false
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
    const { backgroundColor, textColor } = getNewCategoryDefaultColors();
    return this.store.createRecord("category", {
      color: backgroundColor,
      text_color: textColor,
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
      category_localizations: [],
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
        group_name: this.site.groups.find((g) => g.id === 0).name,
        permission_type: 1,
      },
    ];
  }
}
