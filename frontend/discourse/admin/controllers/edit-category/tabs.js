import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action, getProperties } from "@ember/object";
import { and } from "@ember/object/computed";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { AUTO_GROUPS } from "discourse/lib/constants";
import discourseComputed from "discourse/lib/decorators";
import { trackedArray } from "discourse/lib/tracked-tools";
import DiscourseURL from "discourse/lib/url";
import { defaultHomepage } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";

const FIELD_LIST = [
  "name",
  "slug",
  "parent_category_id",
  "description",
  "color",
  "text_color",
  "style_type",
  "emoji",
  "icon",
  "localizations",
  "position",
  "num_featured_topics",
  "search_priority",
  "allow_badges",
  "topic_featured_link_allowed",
  "navigate_to_first_post_after_read",
  "all_topics_wiki",
  "allow_unlimited_owner_edits_on_first_post",
  "moderating_group_ids",
  "auto_close_hours",
  "auto_close_based_on_last_post",
  "default_view",
  "default_top_period",
  "sort_order",
  "sort_ascending",
  "default_list_filter",
  "show_subcategory_list",
  "subcategory_list_style",
  "read_only_banner",
  "email_in",
  "email_in_allow_strangers",
  "mailinglist_mirror",
];

const SHOW_ADVANCED_TABS_KEY = "category_edit_show_advanced_tabs";

export default class EditCategoryTabsController extends Controller {
  @service currentUser;
  @service dialog;
  @service site;
  @service router;
  @service keyValueStore;

  @tracked breadcrumbCategories = this.site.get("categoriesList");
  @tracked
  showAdvancedTabs =
    this.keyValueStore.getItem(SHOW_ADVANCED_TABS_KEY) === "true";
  @tracked selectedTab = "general";
  @tracked previewName = "";
  @tracked previewColor = "";
  @tracked previewTextColor = "";
  @tracked previewStyleType = "";
  @tracked previewEmoji = "";
  @tracked previewIcon = "";
  @tracked previewParentCategoryId = null;
  @trackedArray panels = [];
  saving = false;
  deleting = false;
  showTooltip = false;
  createdCategory = false;
  expandedMenu = false;
  parentParams = null;
  validators = [];
  textColors = ["000000", "FFFFFF"];

  @and("showTooltip", "model.cannot_delete_reason") showDeleteReason;

  get formData() {
    const data = getProperties(this.model, ...FIELD_LIST);

    if (!this.model.styleType) {
      data.style_type = "icon";
    }

    return data;
  }

  @action
  canSaveForm(transientData) {
    if (!transientData.name) {
      return false;
    }

    if (this.saving || this.deleting) {
      return true;
    }

    return true;
  }

  @discourseComputed("saving", "deleting")
  deleteDisabled(saving, deleting) {
    return deleting || saving || false;
  }

  @discourseComputed("name")
  categoryName(name) {
    name = name || "";
    return name.trim().length > 0 ? name : i18n("preview");
  }

  @discourseComputed("saving", "model.id")
  saveLabel(saving, id) {
    if (saving) {
      return "saving";
    }
    return id ? "category.save" : "category.create";
  }

  get baseTitle() {
    if (this.model.id) {
      return i18n("category.edit_dialog_title", {
        categoryName: this.model.name,
      });
    }

    return i18n("category.create");
  }

  get showPreviewBadge() {
    if (this.model.id) {
      return false;
    }

    const name = this.previewName || this.model.name || "";
    return name.trim().length > 0;
  }

  get previewBadge() {
    if (!this.showPreviewBadge) {
      return null;
    }

    const permissions = this.model.permissions;
    let isRestricted = false;

    if (!permissions || permissions.length === 0) {
      isRestricted = true;
    } else {
      const onlyEveryone =
        permissions.length === 1 &&
        (permissions[0].group_id === AUTO_GROUPS.everyone.id ||
          permissions[0].group_name === "everyone");
      isRestricted = !onlyEveryone;
    }

    const parentId =
      this.previewParentCategoryId ?? this.model.parent_category_id;

    const previewCategory = {
      name: this.previewName || this.model.name,
      color: this.previewColor || this.model.color,
      text_color: this.previewTextColor || this.model.text_color,
      style_type: this.previewStyleType || this.model.style_type || "icon",
      emoji: this.previewEmoji || this.model.emoji,
      icon: this.previewIcon || this.model.icon,
      read_restricted: isRestricted,
      parent_category_id: parentId,
    };

    const badge = categoryBadgeHTML(previewCategory, {
      link: false,
      previewColor: true,
    });

    return htmlSafe(badge);
  }

  @action
  updatePreview(data) {
    if (data.name !== undefined) {
      this.previewName = data.name;
    }
    if (data.color !== undefined) {
      this.previewColor = data.color;
    }
    if (data.text_color !== undefined) {
      this.previewTextColor = data.text_color;
    }
    if (data.style_type !== undefined) {
      this.previewStyleType = data.style_type;
    }
    if (data.emoji !== undefined) {
      this.previewEmoji = data.emoji;
    }
    if (data.icon !== undefined) {
      this.previewIcon = data.icon;
    }
    if (data.parent_category_id !== undefined) {
      this.previewParentCategoryId = data.parent_category_id;
    }
  }

  @action
  resetPreview() {
    this.previewName = "";
    this.previewColor = "";
    this.previewTextColor = "";
    this.previewStyleType = "";
    this.previewEmoji = "";
    this.previewIcon = "";
    this.previewParentCategoryId = null;
  }

  @action
  setSelectedTab(tab) {
    this.selectedTab = tab;
    this.showAdvancedTabs = this.showAdvancedTabs || tab !== "general";
  }

  @action
  registerValidator(validator) {
    this.validators.push(validator);
  }

  @action
  isLeavingForm(transition) {
    return !transition.targetName.startsWith("editCategory.tabs");
  }

  _wouldLoseAccess(category = this.model) {
    if (this.currentUser.admin) {
      return false;
    }

    const permissions = category.permissions;
    if (!permissions?.length) {
      return false;
    }

    const userGroupIds = new Set(this.currentUser.groups.map((g) => g.id));

    return !permissions.some(
      (p) =>
        p.group_id === AUTO_GROUPS.everyone.id || userGroupIds.has(p.group_id)
    );
  }

  @action
  async saveCategory(data) {
    if (this.validators.some((validator) => validator())) {
      return;
    }

    this.model.setProperties(data);

    // If permissions is empty or not set, ensure it's an empty array (public category)
    if (!this.model.permissions || this.model.permissions.length === 0) {
      this.model.set("permissions", []);
    }

    const lostAccess = this._wouldLoseAccess();

    if (lostAccess) {
      const confirmed = await this.dialog.yesNoConfirm({
        message: i18n("category.errors.self_lockout"),
      });

      if (!confirmed) {
        return;
      }
    }

    this.set("saving", true);

    try {
      const result = await this.model.save();
      const updatedModel = this.site.updateCategory(result.category);
      updatedModel.setupGroupsAndPermissions();

      if (lostAccess) {
        this.router.transitionTo(`discovery.${defaultHomepage()}`);
        return;
      }

      this.set("saving", false);

      if (!this.model.id) {
        this.router.transitionTo(
          "editCategory",
          Category.slugFor(updatedModel)
        );
      }

      // ensure breadcrumbs contain the updated category model
      this.breadcrumbCategories = this.site.categoriesList.map((c) =>
        c.id === this.model.id ? updatedModel : c
      );
    } catch (error) {
      this.set("saving", false);
      popupAjaxError(error);
      this.model.set("parent_category_id", undefined);
    }
  }

  @action
  deleteCategory() {
    this.set("deleting", true);
    this.dialog.deleteConfirm({
      title: i18n("category.delete_confirm"),
      didConfirm: () => {
        this.model
          .destroy()
          .then(() => {
            this.router.transitionTo("discovery.categories");
          })
          .catch(() => {
            this.displayErrors([i18n("category.delete_error")]);
          })
          .finally(() => {
            this.set("deleting", false);
          });
      },
      didCancel: () => this.set("deleting", false),
    });
  }

  @action
  toggleDeleteTooltip() {
    this.toggleProperty("showTooltip");
  }

  @action
  goBack() {
    DiscourseURL.routeTo(this.model.url);
  }

  @action
  toggleAdvancedTabs() {
    this.showAdvancedTabs = !this.showAdvancedTabs;

    // Save preference to localStorage
    this.keyValueStore.setItem(
      SHOW_ADVANCED_TABS_KEY,
      this.showAdvancedTabs.toString()
    );

    // Always ensure we're on general tab after toggling
    next(() => {
      this.selectedTab = "general";
    });
  }
}
