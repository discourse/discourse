export default Ember.Component.extend({
  didInsertElement() {
    this._super(...arguments);
    $(".d-modal.fixed-modal")
      .modal("hide")
      .addClass("hidden");
  }
});
