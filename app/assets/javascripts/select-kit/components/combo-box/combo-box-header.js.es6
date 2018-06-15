import SelectKitHeaderComponent from "select-kit/components/select-kit/select-kit-header";

export default SelectKitHeaderComponent.extend({
  layoutName: "select-kit/templates/components/combo-box/combo-box-header",
  classNames: "combo-box-header",

  clearable: Ember.computed.alias("options.clearable"),
  caretUpIcon: Ember.computed.alias("options.caretUpIcon"),
  caretDownIcon: Ember.computed.alias("options.caretDownIcon"),
  shouldDisplayClearableButton: Ember.computed.and(
    "clearable",
    "computedContent.hasSelection"
  )
});
