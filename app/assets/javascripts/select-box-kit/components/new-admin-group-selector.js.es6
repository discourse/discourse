import MultiComboBoxComponent from "select-box-kit/components/multi-combo-box";
import { on, observes } from "ember-addons/ember-computed-decorators";

export default MultiComboBoxComponent.extend({
  classNames: ["new-admin-group-selector"],

  actions: {
    onSelectRow(content) {
      this._super();

      this.triggerAction({ action: "groupAdded", actionContext: content });
    },

    onDeselectContent(content) {
      this._super();

      this.triggerAction({
        action: "groupRemoved",
        actionContext: this.valueForContent(content)
      });
    }
  }
});
