import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNames: "select-box-header",

  classNameBindings: ["focused:is-focused"],

  showClearButton: false,

  didReceiveAttrs() {
    this._super();

    this._setCaretIcon();
  },

  @computed("clearable", "selectedId")
  showClearButton(clearable, selectedId) {
    return clearable === true && !Ember.isNone(selectedId);
  },

  click() {
    this.sendAction("onToggle");
  },

  actions: {
    clearSelection() {
      this.sendAction("onClearSelection");
    }
  },

  _setCaretIcon() {
    if(this.get("expanded")) {
      this.set("caretIcon", this.get("caretUpIcon"));
    } else {
      this.set("caretIcon", this.get("caretDownIcon"));
    }
  }
});
