import I18n from "I18n";
import Controller from "@ember/controller";
import discourseComputed, { on } from "discourse-common/utils/decorators";
import bootbox from "bootbox";
import { extractError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
import { readOnly, alias } from "@ember/object/computed";

export default Controller.extend({
  selectedTab: alias("model.params.tab"),
  saving: false,
  deleting: false,
  panels: null,
  hiddenTooltip: true,
  createdCategory: false,
  expandedMenu: false,
  mobileView: readOnly("site.mobileView"),

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
              createdCategory: true,
            });
          }
        })
        .catch((error) => {
          bootbox.alert(extractError(error));
          this.set("saving", false);
        });
    },

    deleteCategory() {
      this.set("deleting", true);
      bootbox.confirm(
        I18n.t("category.delete_confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        (result) => {
          if (result) {
            this.model.destroy().then(
              () => {
                this.transitionToRoute("discovery.categories");
              },
              () => {
                this.displayErrors([I18n.t("category.delete_error")]);
                this.set("deleting", false);
              }
            );
          } else {
            this.set("deleting", false);
          }
        }
      );
    },

    toggleDeleteTooltip() {
      this.toggleProperty("hiddenTooltip");
    },

    goBack() {
      if (this.model.createdCategory) {
        DiscourseURL.redirectTo(this.model.url);
      } else {
        DiscourseURL.routeTo(this.model.url);
      }
    },

    toggleMenu() {
      this.toggleProperty("expandedMenu");
    },
  },
});
