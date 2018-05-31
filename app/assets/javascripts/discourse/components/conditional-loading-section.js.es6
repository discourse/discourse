export default Ember.Component.extend({
  classNames: ["conditional-loading-section"],

  classNameBindings: ["isLoading"],

  isLoading: false,

  title: I18n.t("conditional_loading_section.loading")
});
