export default Ember.Component.extend({
  classNames: ["create-account"],

  didInsertElement() {
    this._super();

    if ($.cookie("email")) {
      this.set("email", $.cookie("email"));
    }

    this.$().on("keydown.discourse-create-account", e => {
      if (!this.get("disabled") && e.keyCode === 13) {
        e.preventDefault();
        e.stopPropagation();
        this.sendAction();
        return false;
      }
    });
  },

  willDestroyElement() {
    this._super();
    this.$().off("keydown.discourse-create-account");
  }
});
