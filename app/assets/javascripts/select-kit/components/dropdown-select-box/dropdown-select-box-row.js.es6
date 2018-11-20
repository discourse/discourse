import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";

export default SelectKitRowComponent.extend({
  layoutName:
    "select-kit/templates/components/dropdown-select-box/dropdown-select-box-row",
  classNames: "dropdown-select-box-row",

  description: Ember.computed.alias(
    "computedContent.originalContent.description"
  )
});
