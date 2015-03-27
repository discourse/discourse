// Mix this in to a view that has a `archetype` property to automatically
// add it to the body as the view is entered / left / model is changed.
// This is used for keeping the `body` style in sync for the background image.
export default {
  _enterView: function() { this.get('archetype'); }.on('init'),

  _removeClasses() {
    $('body').removeClass(function(idx, css) {
      return (css.match(/\barchetype-\S+/g) || []).join(' ');
    });
  },

  _categoryChanged: function() {
    const archetype = this.get('archetype');
    this._removeClasses();

    if (archetype) {
      $('body').addClass('archetype-' + archetype);
    }
  }.observes('archetype'),

  _leaveView: function() { this._removeClasses(); }.on('willDestroyElement')
};
