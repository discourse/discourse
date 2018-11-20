import ModalFunctionality from "discourse/mixins/modal-functionality";
import { default as computed } from "ember-addons/ember-computed-decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";

const COMPONENT = "component";

export default Ember.Controller.extend(ModalFunctionality, {
  types: [
    { name: I18n.t("admin.customize.theme.theme"), value: "theme" },
    { name: I18n.t("admin.customize.theme.component"), value: COMPONENT }
  ],
  selectedType: "theme",
  name: I18n.t("admin.customize.new_style"),
  themesController: Ember.inject.controller("adminCustomizeThemes"),
  loading: false,

  @computed("selectedType")
  component(type) {
    return type === COMPONENT;
  },

  actions: {
    createTheme() {
      this.set("loading", true);
      const theme = this.store.createRecord("theme");
      theme
        .save({ name: this.get("name"), component: this.get("component") })
        .then(() => {
          this.get("themesController").send("addTheme", theme);
          this.send("closeModal");
        })
        .catch(popupAjaxError)
        .finally(() => this.set("loading", false));
    }
  }
});
