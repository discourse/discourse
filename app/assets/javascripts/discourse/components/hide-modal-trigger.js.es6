export default Ember.View.extend({
  didInsertElement() {
    this._super();
    $('#discourse-modal').modal('hide');
  }
});
