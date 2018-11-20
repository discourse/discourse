export default Ember.Component.extend({
  didInsertElement() {
    this._super();
    $(".d-modal.fixed-modal")
      .modal("hide")
      .addClass("hidden");
  }
});
