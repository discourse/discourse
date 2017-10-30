import SelectBoxKitRowComponent from "select-box-kit/components/select-box-kit/select-box-kit-row";

export default SelectBoxKitRowComponent.extend({
  layoutName: "select-box-kit/templates/components/dropdown-select-box/dropdown-select-box-row",
  classNames: "dropdown-select-box-row",

  name: Ember.computed.alias("content.name"),
  description: Ember.computed.alias("content.originalContent.description")
});
