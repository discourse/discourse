export default Ember.View.extend(Discourse.ScrollTop, {
  _scrollOnModelChange: function() {
    this._scrollTop();
  }.observes('controller.model.id')
});
