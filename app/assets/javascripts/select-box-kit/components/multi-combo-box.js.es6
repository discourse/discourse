import SelectBoxKitComponent from "select-box-kit/components/select-box-kit";
import computed from "ember-addons/ember-computed-decorators";

export default SelectBoxKitComponent.extend({
  classNames: ["multi-combobox"],

  headerComponent: "multi-combo-box/multi-combo-box-header",

  headerText: null,

  @computed("content.[]", "filter", "valueAttribute", "valueIds")
  filteredContent(content, filter, valueAttribute, valueIds) {
    let filteredContent = this._super();

    return filteredContent.filter((content) => {
      return !valueIds.includes(this.valueForContent(content));
    });
  },
});
