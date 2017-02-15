export default Ember.Component.extend({
  didInsertElement() {
    this._super();
    $('#discourse-modal').modal('hide');
  }
});
