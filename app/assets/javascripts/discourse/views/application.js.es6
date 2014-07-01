export default Ember.View.extend({
  _appendCategoryClass: function(obj, key) {
    var newClass = Em.get(obj, key);
    if (newClass) {
      $('body').addClass('category-' + newClass);
    }
  }.observes('controller.styleCategory.id'),

  _removeOldClass: function(obj, key) {
    var oldClass = Em.get(obj, key);
    if (oldClass) {
      $('body').removeClass('category-' + oldClass);
    }
  }.observesBefore('controller.styleCategory.id')
});
