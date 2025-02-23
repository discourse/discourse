import Controller from "@ember/controller";
import { action } from "@ember/object";
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

export default class EditCategoryTabsController extends Controller {
  @service dialog;
  @service site;
  @service router;

  selectedTab = "general";
  saving = false;
  deleting = false;
  panels = [];
  showTooltip = false;
  createdCategory = false;
  expandedMenu = false;
  parentParams = null;
  validators = [];

  @and("showTooltip", "model.cannot_delete_reason") showDeleteReason;

  @discourseComputed("saving", "model.name", "model.color", "deleting")
  disabled(saving, name, color, deleting) {
    if (saving || deleting) {
      return true;
    }
    if (!name) {
      return true;
    }
    if (!color) {
      return true;
    }
    return false;
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
  saveCategory() {
    if (this.validators.some((validator) => validator())) {
      return;
    }

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
    this.dialog.yesNoConfirm({
      message: i18n("category.delete_confirm"),
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
