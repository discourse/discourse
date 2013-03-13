/**
  CSS transitions are a PITA, often we need to queue some js after a transition, this helper ensures
  it happens after the transition.

  SO: http://stackoverflow.com/questions/9943435/css3-animation-end-techniques


  @class TransitionHelper
  @namespace Discourse
  @module Discourse
**/

var dummy, eventNameHash, transitionEnd, _getTransitionEndEventName;

dummy = document.createElement("div");

eventNameHash = {
  webkit: "webkitTransitionEnd",
  Moz: "transitionend",
  O: "oTransitionEnd",
  ms: "MSTransitionEnd"
};

_getTransitionEndEventName = function() {
  var retValue;
  retValue = "transitionend";
  Object.keys(eventNameHash).some(function(vendor) {
    if (vendor + "TransitionProperty" in dummy.style) {
      retValue = eventNameHash[vendor];
      return true;
    }
  });
  return retValue;
};
transitionEnd = _getTransitionEndEventName();

Discourse.TransitionHelper = {
  after: function(element, callback) {
    return $(element).on(transitionEnd, callback);
  }
};


