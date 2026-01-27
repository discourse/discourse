import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action, getProperties } from "@ember/object";
import { and } from "@ember/object/computed";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
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

const PREVIEW_FIELD_MAP = {
  name: "previewName",
  color: "previewColor",
  text_color: "previewTextColor",
  style_type: "previewStyleType",
  emoji: "previewEmoji",
  icon: "previewIcon",
  parent_category_id: "previewParentCategoryId",
};

const PREVIEW_DEFAULTS = {
  previewName: "",
  previewColor: "",
  previewTextColor: "",
  previewStyleType: "",
  previewEmoji: "",
  previewIcon: "",
  previewParentCategoryId: null,
};

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
  @tracked previewData = new TrackedObject(PREVIEW_DEFAULTS);
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

  @action
  updatePreview(data) {
    Object.entries(PREVIEW_FIELD_MAP).forEach(([key, previewField]) => {
      if (data[key] !== undefined) {
        this.previewData[previewField] = data[key];
      }
    });
  }

  @action
  resetPreview() {
    Object.entries(PREVIEW_DEFAULTS).forEach(([key, value]) => {
      this.previewData[key] = value;
    });
  }

  @action
  setSelectedTab(tab) {
    this.selectedTab = tab;
    this.showAdvancedTabs = this.showAdvancedTabs || tab !== "general";
  }

  @action
  validateForm(data, { addError }) {
    let hasGeneralTabErrors = false;

    if (!data.name) {
      addError("name", {
        title: i18n("category.name"),
        message: i18n("form_kit.errors.required"),
      });
      hasGeneralTabErrors = true;
    }

    if (data.style_type === "emoji" && !data.emoji) {
      addError("emoji", {
        title: i18n("category.emoji"),
        message: i18n("category.validations.emoji_required"),
      });
      hasGeneralTabErrors = true;
    }

    if (hasGeneralTabErrors && this.selectedTab !== "general") {
      this.selectedTab = "general";
    }
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
