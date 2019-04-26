import ModalFunctionality from "discourse/mixins/modal-functionality";
import DiscourseURL from "discourse/lib/url";
import { extractError } from "discourse/lib/ajax-error";
import computed from "ember-addons/ember-computed-decorators";

// Modal for editing / creating a category
export default Ember.Controller.extend(ModalFunctionality, {
  selectedTab: null,
  saving: false,
  deleting: false,
  panels: null,
  hiddenTooltip: true,

  _initPanels: function() {
    this.set("panels", []);
  }.on("init"),

  onShow() {
    this.changeSize();
    this.titleChanged();
    this.set("hiddenTooltip", true);
  },

  changeSize: function() {
    if (!Ember.isEmpty(this.get("model.description"))) {
      this.set("modal.modalClass", "edit-category-modal full");
    } else {
      this.set("modal.modalClass", "edit-category-modal small");
    }
  }.observes("model.description"),

  @computed("model.id", "model.name")
  title(id, name) {
    if (id) {
      return I18n.t("category.edit_dialog_title", {
        categoryName: name
      });
    }
    return I18n.t("category.create");
  },

  titleChanged: function() {
    this.set("modal.title", this.get("title"));
  }.observes("title"),

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
    saveCategory() {
      const self = this,
        model = this.get("model"),
        parentCategory = this.site
          .get("categories")
          .findBy("id", parseInt(model.get("parent_category_id"), 10));

      this.set("saving", true);
      model.set("parentCategory", parentCategory);

      this.get("model")
        .save()
        .then(function(result) {
          self.set("saving", false);
          self.send("closeModal");
          model.setProperties({
            slug: result.category.slug,
            id: result.category.id
          });
          DiscourseURL.redirectTo("/c/" + Discourse.Category.slugFor(model));
        })
        .catch(function(error) {
          self.flash(extractError(error), "error");
          self.set("saving", false);
        });
    },

    deleteCategory() {
      const self = this;
      this.set("deleting", true);

      this.send("hideModal");
      bootbox.confirm(
        I18n.t("category.delete_confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        function(result) {
          if (result) {
            self
              .get("model")
              .destroy()
              .then(
                function() {
                  // success
                  self.send("closeModal");
                  DiscourseURL.redirectTo("/categories");
                },
                function(error) {
                  self.flash(extractError(error), "error");
                  self.send("reopenModal");
                  self.displayErrors([I18n.t("category.delete_error")]);
                  self.set("deleting", false);
                }
              );
          } else {
            self.send("reopenModal");
            self.set("deleting", false);
          }
        }
      );
    },

    toggleDeleteTooltip() {
      this.toggleProperty("hiddenTooltip");
    }
  }
});
