import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action, getProperties } from "@ember/object";
import { and } from "@ember/object/computed";
import { service } from "@ember/service";
import { underscore } from "@ember/string";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import { NotificationLevels } from "discourse/lib/notification-levels";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import PermissionType from "discourse/models/permission-type";
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
];

export default class EditCategoryTabsController extends Controller {
  @service dialog;
  @service site;
  @service router;

  @tracked breadcrumbCategories = this.site.get("categoriesList");

  selectedTab = "general";
  saving = false;
  deleting = false;
  panels = [];
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
      data.style_type = "square";
    }

    return data;
  }

  @action
  canSaveForm(transientData) {
    if (!transientData.name) {
      return false;
    }

    if (!transientData.color) {
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

  @discourseComputed("model.id", "model.name")
  title(id, name) {
    return id
      ? i18n("category.edit_dialog_title", {
          categoryName: name,
        })
      : i18n("category.create");
  }

  @discourseComputed("selectedTab")
  selectedTabTitle(tab) {
    return i18n(`category.${underscore(tab)}`);
  }

  @action
  registerValidator(validator) {
    this.validators.push(validator);
  }

  @action
  isLeavingForm(transition) {
    return !transition.targetName.startsWith("editCategory.tabs");
  }

  @action
  saveCategory(transientData) {
    if (this.validators.some((validator) => validator())) {
      return;
    }

    this.model.setProperties(transientData);

    this.set("saving", true);

    this.model
      .save()
      .then((result) => {
        if (!this.model.id) {
          this.model.setProperties({
            slug: result.category.slug,
            id: result.category.id,
            can_edit: result.category.can_edit,
            permission: PermissionType.FULL,
            notification_level: NotificationLevels.REGULAR,
          });
          this.site.updateCategory(this.model);
          this.router.transitionTo(
            "editCategory",
            Category.slugFor(this.model)
          );
        }
        // force a reload of the category list to track changes to style type
        this.breadcrumbCategories = this.site.categoriesList.map((c) =>
          c.id === this.model.id ? this.model : c
        );
      })
      .catch((error) => {
        popupAjaxError(error);
        this.model.set("parent_category_id", undefined);
      })
      .finally(() => {
        this.set("saving", false);
      });
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
}
