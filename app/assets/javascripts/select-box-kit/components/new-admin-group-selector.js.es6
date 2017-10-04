import MultiComboBoxComponent from "select-box-kit/components/multi-combo-box";

export default MultiComboBoxComponent.extend({
  classNames: "new-admin-group-selector",

  actions: {
    onSelect(content) {
      this.defaultOnSelect();

      this.triggerAction({ action: "groupAdded", actionContext: content });
    },

    onDeselect(content) {
      this.defaultOnSelect();

      this.triggerAction({
        action: "groupRemoved",
        actionContext: this.valueForContent(content)
      });
    }
  }
});
