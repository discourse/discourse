import SelectBoxKitComponent from "select-box-kit/components/select-box-kit";
import computed from "ember-addons/ember-computed-decorators";
const { isNone } = Ember;

export default SelectBoxKitComponent.extend({
  classNames: "combobox",
  autoFilterable: true,

  @computed("selectedContent.firstObject.name", "computedNone.name")
  computedHeaderText(selectedName, noneName) {
    if (isNone(selectedName)) {
      if (isNone(noneName)) {
        return this._super();
      } else {
        return noneName;
      }
    } else {
      return selectedName;
    }
  }
});
