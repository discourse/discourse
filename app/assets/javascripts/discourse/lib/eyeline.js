/**
  Track visible elemnts on the screen.

  You can register for triggers on:

    `focusChanged`  the top element we're focusing on

    `seenElement`   if we've seen the element

  @class Eyeline
  @namespace Discourse
  @module Discourse
  @uses RSVP.EventTarget
**/
Discourse.Eyeline = function Eyeline(selector) {
  this.selector = selector;
};


/**
  Call this to analyze the positions of all the nodes in a set

  returns: a hash with top, bottom and onScreen items
          {top: , bottom:, onScreen:}
 **/
Discourse.Eyeline.analyze = function(rows) {
  var current, goingUp, i, increment, offset,
      winHeight, winOffset, detected, onScreen,
      bottom, top, outerHeight;

  if (rows.length === 0) return;

  i = parseInt(rows.length / 2, 10);
  increment = parseInt(rows.length / 4, 10);
  goingUp = undefined;
  winOffset = window.pageYOffset || $('html').scrollTop();
  winHeight = window.innerHeight || $(window).height();

  while (true) {
    if (i === 0 || (i >= rows.length - 1)) {
      break;
    }
    current = $(rows[i]);
    offset = current.offset();

    if (offset.top - winHeight < winOffset) {
      if (offset.top + current.outerHeight() - window.innerHeight > winOffset) {
        break;
      } else {
        i = i + increment;
        if (goingUp !== undefined && increment === 1 && !goingUp) {
          break;
        }
        goingUp = true;
      }
    } else {
      i = i - increment;
      if (goingUp !== undefined && increment === 1 && goingUp) {
        break;
      }
      goingUp = false;
    }
    if (increment > 1) {
      increment = parseInt(increment / 2, 10);
      goingUp = undefined;
    }
    if (increment === 0) {
      increment = 1;
      goingUp = undefined;
    }
  }

  onScreen = [];
  bottom = i;
  // quick analysis of whats on screen
  while(true) {
    if(i < 0) { break;}

    current = $(rows[i]);
    offset = current.offset();
    outerHeight = current.outerHeight();

    // on screen
    if(offset.top > winOffset && offset.top + outerHeight < winOffset + winHeight) {
      onScreen.unshift(i);
    } else {

      if(offset.top < winOffset) {
        top = i;
        break;
      } else {
        // bottom
      }
    }
    i -=1;
  }

  return({top: top, bottom: bottom, onScreen: onScreen});

};


/**
  Call this whenever you want to consider what is being seen by the browser

  @method update
**/
Discourse.Eyeline.prototype.update = function() {
  var $elements, atBottom, bottomOffset, docViewBottom, docViewTop, documentHeight, foundElement, windowHeight,
    _this = this;

  docViewTop = $(window).scrollTop();
  windowHeight = $(window).height();
  docViewBottom = docViewTop + windowHeight;
  documentHeight = $(document).height();
  $elements = $(this.selector);
  atBottom = false;

  if (bottomOffset = $elements.last().offset()) {
    atBottom = (bottomOffset.top <= docViewBottom) && (bottomOffset.top >= docViewTop);
  }

  // Whether we've seen any elements in this search
  foundElement = false;

  return $elements.each(function(i, elem) {
    var $elem, elemBottom, elemTop, markSeen;

    $elem = $(elem);
    elemTop = $elem.offset().top;
    elemBottom = elemTop + $elem.height();
    markSeen = false;
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
      _this.trigger('saw', {
        detail: $elem
      });
      if (i === 0) {
        _this.trigger('sawTop', { detail: $elem });
      }
      return false;
    }
    if (i === 0) {
      _this.trigger('sawTop', { detail: $elem });
    }
    if (i === ($elements.length - 1)) {
      return _this.trigger('sawBottom', { detail: $elem });
    }
  });
};


/**
  Call this when we know aren't loading any more elements. Mark the rest as seen

  @method flushRest
**/
Discourse.Eyeline.prototype.flushRest = function() {
  var eyeline = this;
  return $(this.selector).each(function(i, elem) {
    var $elem = $(elem);
    return eyeline.trigger('saw', { detail: $elem });
  });
};

RSVP.EventTarget.mixin(Discourse.Eyeline.prototype);


