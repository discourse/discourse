/**
  This will render a control to edit the `hotness` of a thing. This would be really
  cool to use with a shadow DOM.

  @class HotnessView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.HotnessView = Discourse.View.extend({
  classNames: ['hotness-control'],

  shouldRerender: Discourse.View.renderIfChanged('hotness'),

  render: function(buffer) {
    // Our scale goes to 11!
    for (var i=1; i<12; i++) {
      buffer.push("<button value='" + i + "'");
      if (this.get('hotness') === i) {
        buffer.push(" class='selected'");
      }
      buffer.push(">" + i + "</button>");
    }
  },

  /**
    When the user clicks on a hotness value button, change it.

    @method click
  **/
  click: function(e) {

    var $target = $(e.target);

    if (!$target.is('button')) return;
    this.set('hotness', parseInt($target.val(), 10));

    return false;
  }

});


