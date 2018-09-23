import ModalFunctionality from "discourse/mixins/modal-functionality";
import { default as computed } from "ember-addons/ember-computed-decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { THEMES, COMPONENTS } from "admin/models/theme";

const MIN_NAME_LENGTH = 4;

export default Ember.Controller.extend(ModalFunctionality, {
  saving: false,
  triggerError: false,
  themesController: Ember.inject.controller("adminCustomizeThemes"),
  types: [
    { name: I18n.t("admin.customize.theme.theme"), value: THEMES },
    { name: I18n.t("admin.customize.theme.component"), value: COMPONENTS }
  ],

  @computed("triggerError", "nameTooShort")
  showError(trigger, tooShort) {
    return trigger && tooShort;
  },

  @computed("name")
  nameTooShort(name) {
    return !name || name.length < MIN_NAME_LENGTH;
  },

  @computed("component")
  placeholder(component) {
    if (component) {
      return I18n.t("admin.customize.theme.component_name");
    } else {
      return I18n.t("admin.customize.theme.theme_name");
    }
  },

  @computed("themesController.currentTab")
  selectedType(tab) {
    return tab;
  },

  @computed("selectedType")
  component(type) {
    return type === COMPONENTS;
  },

  actions: {
    createTheme() {
      if (this.get("nameTooShort")) {
        this.set("triggerError", true);
        return;
      }

      this.set("saving", true);
      const theme = this.store.createRecord("theme");
      theme
        .save({ name: this.get("name"), component: this.get("component") })
        .then(() => {
          this.get("themesController").send("addTheme", theme);
          this.send("closeModal");
        })
        .catch(popupAjaxError)
        .finally(() => this.set("saving", false));
    }
  }
});
