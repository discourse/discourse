export default Ember.Component.extend({
  classNames: "select-box-header",

  classNameBindings: ["focused:is-focused"],

  didReceiveAttrs() {
    this._super();

    this._setCaretIcon();
  },

  click(event) {
    this.sendAction("onToggle");
    event.stopPropagation();
  },

  _setCaretIcon() {
    if(this.get("expanded")) {
      this.set("caretIcon", this.get("caretUpIcon"));
    } else {
      this.set("caretIcon", this.get("caretDownIcon"));
    }
  }
});
