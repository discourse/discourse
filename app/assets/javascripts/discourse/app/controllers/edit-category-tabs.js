import { and, readOnly } from "@ember/object/computed";
import discourseComputed, { on } from "discourse-common/utils/decorators";
import Category from "discourse/models/category";
import Controller from "@ember/controller";
import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";
import { NotificationLevels } from "discourse/lib/notification-levels";
import PermissionType from "discourse/models/permission-type";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { underscore } from "@ember/string";
import { inject as service } from "@ember/service";

export default Controller.extend({
  dialog: service(),
  site: service(),
  router: service(),

  selectedTab: "general",
  saving: false,
  deleting: false,
  panels: null,
  showTooltip: false,
  createdCategory: false,
  expandedMenu: false,
  mobileView: readOnly("site.mobileView"),
  parentParams: null,
  showDeleteReason: and("showTooltip", "model.cannot_delete_reason"),

  @on("init")
  _initPanels() {
    this.setProperties({
      panels: [],
      validators: [],
    });
  },

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
  },

  @discourseComputed("saving", "deleting")
  deleteDisabled(saving, deleting) {
    return deleting || saving || false;
  },

  @discourseComputed("name")
  categoryName(name) {
    name = name || "";
    return name.trim().length > 0 ? name : I18n.t("preview");
  },

  @discourseComputed("saving", "model.id")
  saveLabel(saving, id) {
    if (saving) {
      return "saving";
    }
    return id ? "category.save" : "category.create";
  },

  @discourseComputed("model.id", "model.name")
  title(id, name) {
    return id
      ? I18n.t("category.edit_dialog_title", {
          categoryName: name,
        })
      : I18n.t("category.create");
  },

  @discourseComputed("selectedTab")
  selectedTabTitle(tab) {
    return I18n.t(`category.${underscore(tab)}`);
  },

  actions: {
    registerValidator(validator) {
      this.validators.push(validator);
    },

    saveCategory() {
      if (this.validators.some((validator) => validator())) {
        return;
      }
      const model = this.model;
      const parentCategory = this.site.categories.findBy(
        "id",
        parseInt(model.parent_category_id, 10)
      );

      this.set("saving", true);
      model.set("parentCategory", parentCategory);

      model
        .save()
        .then((result) => {
          this.set("saving", false);
          if (!model.id) {
            model.setProperties({
              slug: result.category.slug,
              id: result.category.id,
              can_edit: result.category.can_edit,
              permission: PermissionType.FULL,
              notification_level: NotificationLevels.REGULAR,
            });
            this.site.updateCategory(model);
            this.router.transitionTo("editCategory", Category.slugFor(model));
          }
        })
        .catch((error) => {
          popupAjaxError(error);
          this.set("saving", false);
        });
    },

    deleteCategory() {
      this.set("deleting", true);
      this.dialog.yesNoConfirm({
        message: I18n.t("category.delete_confirm"),
        didConfirm: () => {
          this.model
            .destroy()
            .then(() => {
              this.router.transitionTo("discovery.categories");
            })
            .catch(() => {
              this.displayErrors([I18n.t("category.delete_error")]);
            })
            .finally(() => {
              this.set("deleting", false);
            });
        },
        didCancel: () => this.set("deleting", false),
      });
    },

    toggleDeleteTooltip() {
      this.toggleProperty("showTooltip");
    },

    goBack() {
      DiscourseURL.routeTo(this.model.url);
    },
  },
});
