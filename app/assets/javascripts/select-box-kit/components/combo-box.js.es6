import SelectBoxKitComponent from "select-box-kit/components/select-box-kit";
import computed from "ember-addons/ember-computed-decorators";
const { isNone } = Ember;

export default SelectBoxKitComponent.extend({
  classNames: "combobox",

  @computed("selectedContent.firstObject.name", "computedNone.name")
  headerText(selectedName, noneName) {
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
