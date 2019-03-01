export default Ember.Component.extend({
  classNames: ["create-account"],

  didInsertElement() {
    this._super(...arguments);

    if ($.cookie("email")) {
      this.set("email", $.cookie("email"));
    }

    this.$().on("keydown.discourse-create-account", e => {
      if (!this.get("disabled") && e.keyCode === 13) {
        e.preventDefault();
        e.stopPropagation();
        this.action();
        return false;
      }
    });

    this.$().on("click.dropdown-user-field-label", "[for]", event => {
      const $element = $(event.target);
      const $target = $(`#${$element.attr("for")}`);

      if ($target.is(".select-kit")) {
        event.preventDefault();
        $target.find(".select-kit-header").trigger("click");
      }
    });
  },

  willDestroyElement() {
    this._super(...arguments);

    this.$().off("keydown.discourse-create-account");
    this.$().off("click.dropdown-user-field-label");
  }
});
