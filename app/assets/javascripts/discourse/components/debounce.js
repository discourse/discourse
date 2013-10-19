/**
  Debounce a Javascript function. This means if it's called many times in a time limit it
  should only be executed once (at the end of the limit counted from the last call made).
  Original function will be called with the context and arguments from the last call made.

  @method debounce
  @module Discourse
  @param {function} func The function to debounce
  @param {Number} wait how long to wait
**/
Discourse.debounce = function(func, wait) {
  var self, args;
  var later = function() {
    func.apply(self, args);
  };

  return function() {
    self = this;
    args = arguments;

    Ember.run.debounce(null, later, wait);
  };
};

/**
  Debounce a javascript function that returns a promise. If it's called too soon it
  will return a promise that is never resolved.

  @method debouncePromise
  @module Discourse
  @param {function} func The function to debounce
  @param {Number} wait how long to wait
**/
Discourse.debouncePromise = function(func, wait) {
  var timeout = null;
  var args = null;
  var context = null;

  return function() {
    context = this;
    var promise = Ember.Deferred.create();
    args = arguments;

    if (!timeout) {
      timeout = Em.run.later(function () {
        timeout = null;
        func.apply(context, args).then(function (y) {
          promise.resolve(y);
        });
      }, wait);
    }

    return promise;
  };
};

