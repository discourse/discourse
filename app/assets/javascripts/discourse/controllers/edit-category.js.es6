import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import DiscourseURL from "discourse/lib/url";
import { extractError } from "discourse/lib/ajax-error";
import {
  default as computed,
  on,
  observes
} from "ember-addons/ember-computed-decorators";

export default Controller.extend(ModalFunctionality, {
  selectedTab: null,
  saving: false,
  deleting: false,
  panels: null,
  hiddenTooltip: true,

  @on("init")
  _initPanels() {
    this.setProperties({
      panels: [],
      validators: []
    });
  },

  onShow() {
    this.changeSize();
    this.titleChanged();
    this.set("hiddenTooltip", true);
  },

  @observes("model.description")
  changeSize() {
    if (!Ember.isEmpty(this.get("model.description"))) {
      this.set("modal.modalClass", "edit-category-modal full");
    } else {
      this.set("modal.modalClass", "edit-category-modal small");
    }
  },

  @computed("model.{id,name}")
  title(model) {
    if (model.id) {
      return I18n.t("category.edit_dialog_title", {
        categoryName: model.name
      });
    }
    return I18n.t("category.create");
  },

  @observes("title")
  titleChanged() {
    this.set("modal.title", this.title);
  },

  @computed("saving", "model.name", "model.color", "deleting")
  disabled(saving, name, color, deleting) {
    if (saving || deleting) return true;
    if (!name) return true;
    if (!color) return true;
    return false;
  },

  @computed("saving", "deleting")
  deleteDisabled(saving, deleting) {
    return deleting || saving || false;
  },

  @computed("name")
  categoryName(name) {
    name = name || "";
    return name.trim().length > 0 ? name : I18n.t("preview");
  },

  @computed("saving", "model.id")
  saveLabel(saving, id) {
    if (saving) return "saving";
    return id ? "category.save" : "category.create";
  },

  actions: {
    registerValidator(validator) {
      this.validators.push(validator);
    },

    saveCategory() {
      if (this.validators.some(validator => validator())) {
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
        .then(result => {
          this.set("saving", false);
          this.send("closeModal");
          model.setProperties({
            slug: result.category.slug,
            id: result.category.id
          });
          DiscourseURL.redirectTo("/c/" + Discourse.Category.slugFor(model));
        })
        .catch(error => {
          this.flash(extractError(error), "error");
          this.set("saving", false);
        });
    },

    deleteCategory() {
      this.set("deleting", true);

      this.send("hideModal");
      bootbox.confirm(
        I18n.t("category.delete_confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        result => {
          if (result) {
            this.model.destroy().then(
              () => {
                // success
                this.send("closeModal");
                DiscourseURL.redirectTo("/categories");
              },
              error => {
                this.flash(extractError(error), "error");
                this.send("reopenModal");
                this.displayErrors([I18n.t("category.delete_error")]);
                this.set("deleting", false);
              }
            );
          } else {
            this.send("reopenModal");
            this.set("deleting", false);
          }
        }
      );
    },

    toggleDeleteTooltip() {
      this.toggleProperty("hiddenTooltip");
    }
  }
});
