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
  var self, args, promise;
  var later = function() {
    func.apply(self, args).then(function (funcResult) {
      promise.resolve(funcResult);
    });
  };

  return function() {
    self = this;
    args = arguments;
    promise = Ember.Deferred.create();

    Ember.run.debounce(null, later, wait);

    return promise;
  };
};
