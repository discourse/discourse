import Component from "@ember/component";
export default Component.extend({
  classNames: ["conditional-loading-section"],

  classNameBindings: ["isLoading"],

  isLoading: false,

  title: I18n.t("conditional_loading_section.loading")
});
