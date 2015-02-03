// Mix this in to a view that has a `categorySlug` property to automatically
// add it to the body as the view is entered / left / model is changed.
// This is used for keeping the `body` style in sync for the background image.
export default {
  _enterView: function() { this.get('categorySlug'); }.on('init'),

  _removeClasses: function() {
    $('body').removeClass(function(idx, css) {
      return (css.match(/\bcategory-\S+/g) || []).join(' ');
    });
  },

  _categoryChanged: function() {
    var categorySlug = this.get('categorySlug');
    this._removeClasses();

    if (categorySlug) {
      $('body').addClass('category-' + categorySlug);
    }
  }.observes('categorySlug'),

  _leaveView: function() { this._removeClasses(); }.on('willDestroyElement')
};
