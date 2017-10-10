import SelectBoxKitComponent from "select-box-kit/components/select-box-kit";
import computed from "ember-addons/ember-computed-decorators";

export default SelectBoxKitComponent.extend({
  classNames: "combobox",

  @computed("selectedContents.firstObject.name", "computedNone.name")
  headerText(selectedName, noneName) {
    if (Ember.isNone(selectedName)) {
      if (Ember.isNone(noneName)) {
        return this._super();
      } else {
        return noneName;
      }
    } else {
      return selectedName;
    }
  }
});
