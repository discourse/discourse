/**
  This view handles search facilities of Discourse

  @class SearchView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.SearchView = Discourse.View.extend({
  tagName: 'div',
  classNames: ['d-dropdown'],
  elementId: 'search-dropdown',
  templateName: 'search',

  didInsertElement: function() {
    // Delegate ESC to the composer
    var controller = this.get('controller');
    return $('body').on('keydown.search', function(e) {
      if ($('#search-dropdown').is(':visible')) {
        switch (e.which) {
          case 13:
            return controller.select();
          case 38:
            return controller.moveUp();
          case 40:
            return controller.moveDown();
        }
      }
    });
  }

});


