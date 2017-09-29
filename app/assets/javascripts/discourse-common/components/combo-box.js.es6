import SelectBoxComponent from "discourse/components/select-box";

export default SelectBoxComponent.extend({
  classNames: ['combobox'],

  actions: {
    onSelectRow(content) {
      this._super();
      console.log("selecting row", content)
      this.set("value", content);
    }
  }
});
