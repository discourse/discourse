import ComboBoxComponent from "select-kit/components/combo-box";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["topic-footer-mobile-dropdown"],
  classNames: "topic-footer-mobile-dropdown",
  filterable: false,
  autoFilterable: false,
  allowInitialValueMutation: false,
  allowAutoSelectFirst: false,
  nameProperty: "label",
  isHidden: Ember.computed.empty("content"),

  computeHeaderContent() {
    const content = this._super(...arguments);

    content.name = I18n.t("topic.controls");
    return content;
  },

  mutateAttributes() {},

  willComputeContent(content) {
    content = this._super(content);

    // TODO: this is for backward compat reasons, should be removed
    // when plugins have been updated for long enough
    content.forEach(c => {
      if (c.name) {
        c.label = c.name;
      }
    });

    return content;
  }
});
