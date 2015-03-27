// Mix this in to a view that has a `archetype` property to automatically
// add it to the body as the view is entered / left / model is changed.
// This is used for keeping the `body` style in sync for the background image.
export default {
  _init: function() { this.get('archetype'); }.on('init'),

  _cleanUp() {
    $('body').removeClass((_, css) => (css.match(/\barchetype-\S+/g) || []).join(' '));
  },

  _archetypeChanged: function() {
    const archetype = this.get('archetype');
    this._cleanUp();

    if (archetype) {
      $('body').addClass('archetype-' + archetype);
    }
  }.observes('archetype'),

  _willDestroyElement: function() { this._cleanUp(); }.on('willDestroyElement')
};
