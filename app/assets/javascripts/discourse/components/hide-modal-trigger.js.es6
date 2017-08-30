export default Ember.Component.extend({
  didInsertElement() {
    this._super();
    $('.d-modal').modal('hide').addClass('hidden');
  }
});
