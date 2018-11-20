import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";

export default SelectKitRowComponent.extend({
  layoutName: "select-kit/templates/components/tag-drop/tag-drop-row",
  classNames: "tag-drop-row",

  tagId: Ember.computed.alias("computedContent.value")
});
