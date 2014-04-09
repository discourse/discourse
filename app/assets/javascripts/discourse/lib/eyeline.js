/**
  Track visible elemnts on the screen.

  @class Eyeline
  @namespace Discourse
  @module Discourse
  @uses RSVP.EventTarget
**/
Discourse.Eyeline = function Eyeline(selector) {
  this.selector = selector;
};

/**
  Call this whenever you want to consider what is being seen by the browser

  @method update
**/
Discourse.Eyeline.prototype.update = function() {
  var docViewTop = $(window).scrollTop(),
      windowHeight = $(window).height(),
      docViewBottom = docViewTop + windowHeight,
      $elements = $(this.selector),
      atBottom = false,
      bottomOffset = $elements.last().offset(),
      self = this;

  if (bottomOffset) {
    atBottom = (bottomOffset.top <= docViewBottom) && (bottomOffset.top >= docViewTop);
  }

  return $elements.each(function(i, elem) {
    var $elem = $(elem),
        elemTop = $elem.offset().top,
        elemBottom = elemTop + $elem.height(),
        markSeen = false;

    // Make sure the element is visible
    if (!$elem.is(':visible')) return true;

    // It's seen if...
    // ...the element is vertically within the top and botom
    if ((elemTop <= docViewBottom) && (elemTop >= docViewTop)) markSeen = true;

    // ...the element top is above the top and the bottom is below the bottom (large elements)
    if ((elemTop <= docViewTop) && (elemBottom >= docViewBottom)) markSeen = true;

    // ...we're at the bottom and the bottom of the element is visible (large bottom elements)
    if (atBottom && (elemBottom >= docViewTop)) markSeen = true;

    if (!markSeen) return true;

    // If you hit the bottom we mark all the elements as seen. Otherwise, just the first one
    if (!atBottom) {
      self.trigger('saw', { detail: $elem });
      if (i === 0) {
        self.trigger('sawTop', { detail: $elem });
      }
      return false;
    }
    if (i === 0) {
      self.trigger('sawTop', { detail: $elem });
    }
    if (i === ($elements.length - 1)) {
      return self.trigger('sawBottom', { detail: $elem });
    }
  });
};


/**
  Call this when we know aren't loading any more elements. Mark the rest as seen

  @method flushRest
**/
Discourse.Eyeline.prototype.flushRest = function() {
  var self = this;
  $(this.selector).each(function(i, elem) {
    return self.trigger('saw', { detail: $(elem) });
  });
};

RSVP.EventTarget.mixin(Discourse.Eyeline.prototype);


