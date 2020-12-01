import Component from "@ember/component";
import I18n from "I18n";
export default Component.extend({
  classNames: ["conditional-loading-section"],

  classNameBindings: ["isLoading"],

  isLoading: false,

  title: I18n.t("conditional_loading_section.loading"),
});
