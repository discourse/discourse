// Mix this in to a view that has a `categoryId` property to automatically
// add it to the body as the view is entered / left / model is changed.
// This is used for keeping the `body` style in sync for the background image.
export default {
  _observeOnce: function() { this.get('categoryId'); }.on('init'),

  _removeClasses: function() {
    $('body').removeClass(function(idx, css) {
      return (css.match(/\bcategory-\d+/g) || []).join(' ');
    });
  },

  _categoryChanged: function() {
    var categoryId = this.get('categoryId');
    this._removeClasses();

    if (categoryId) {
      $('body').addClass('category-' + categoryId);
    }
  }.observes('categoryId'),

  _leaveView: function() { this._removeClasses(); }.on('willDestroyElement')
};
