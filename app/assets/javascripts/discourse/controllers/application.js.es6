export default Ember.Controller.extend({
  styleCategory: null,

  backgroundClass: function() {
    var id = this.get('styleCategory.id');
    if (Em.isNone(id)) { return; }
    return "category-" + this.get('styleCategory.id');
  }.property('styleCategory')
});
