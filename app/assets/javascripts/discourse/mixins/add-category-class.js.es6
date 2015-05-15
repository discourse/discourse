// Mix this in to a view that has a `categoryFullSlug` property to automatically
// add it to the body as the view is entered / left / model is changed.
// This is used for keeping the `body` style in sync for the background image.
export default {
  _enterView: function() { this.get('categoryFullSlug'); }.on('init'),

  _removeClasses() {
    $('body').removeClass((_, css) => (css.match(/\bcategory-\S+/g) || []).join(' '));
  },

  _categoryChanged: function() {
    const categoryFullSlug = this.get('categoryFullSlug');
    this._removeClasses();

    if (categoryFullSlug) {
      $('body').addClass('category-' + categoryFullSlug);
    }
  }.observes('categoryFullSlug').on('init'),

  _leaveView: function() { this._removeClasses(); }.on('willDestroyElement')
};
