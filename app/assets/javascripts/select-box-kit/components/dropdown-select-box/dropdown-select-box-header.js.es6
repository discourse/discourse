import SelectBoxKitHeaderComponent from "select-box-kit/components/select-box-kit/select-box-kit-header";

export default SelectBoxKitHeaderComponent.extend({
  layoutName: "select-box-kit/templates/components/dropdown-select-box/dropdown-select-box-header",
  classNames: "dropdown-select-box-header",

  name: Ember.computed.alias("computedContent.name"),
  icons: Ember.computed.alias("computedContent.icons")
});
