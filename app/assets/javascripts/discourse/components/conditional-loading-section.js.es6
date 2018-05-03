import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNames: ["conditional-loading-section"],

  classNameBindings: ["isLoading"],

  isLoading: false,

  @computed("title")
  computedTitle(title) {
    return title || I18n.t("conditional_loading_section.loading");
  }
});
