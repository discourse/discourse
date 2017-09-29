export default Ember.Component.extend({
  layoutName: "select-box-kit/templates/components/select-box-kit/select-box-kit-header",

  classNames: "header",

  classNameBindings: ["isDocused"],

  didReceiveAttrs() {
    this._super();

    this._setCaretIcon();
  },

  click(event) {
    this.sendAction("onToggle");
    event.stopPropagation();
  },

  _setCaretIcon() {
    if(this.get("isExpanded") === true) {
      this.set("caretIcon", this.get("caretUpIcon"));
    } else {
      this.set("caretIcon", this.get("caretDownIcon"));
    }
  }
});
