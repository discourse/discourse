export default Ember.Component.extend({
  classNames: "select-box-header",

  classNameBindings: ["focused:is-focused"],

  didReceiveAttrs() {
    this._super();

    this._setCaretIcon();
  },

  click() {
    this.sendAction("onToggle");
  },

  _setCaretIcon() {
    if(this.get("expanded")) {
      this.set("caretIcon", this.get("caretUpIcon"));
    } else {
      this.set("caretIcon", this.get("caretDownIcon"));
    }
  }
});
