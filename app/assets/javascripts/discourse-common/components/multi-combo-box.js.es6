import SelectBoxComponent from "discourse-common/components/select-box";
import { on, observes } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";

export default SelectBoxComponent.extend({
  classNames: ["multi-combobox"],

  selectBoxHeaderComponent: "multi-combo-box/header",

  headerText: null,

  @computed("content.[]", "filter", "valueAttribute", "valueIds")
  filteredContent(content, filter, valueAttribute, valueIds) {
    let filteredContent = this._super();

    return filteredContent.filter((content) => {
      return !valueIds.includes(this.valueForContent(content));
    });
  },
});
