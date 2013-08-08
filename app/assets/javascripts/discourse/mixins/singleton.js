/**
  This mixin allows a class to return a singleton, as well as a method to quickly
  read/write attributes on the singleton.

  @class Discourse.Singleton
  @extends Ember.Mixin
  @namespace Discourse
  @module Discourse
**/
Discourse.Singleton = Em.Mixin.create({

  /**
    Returns the current singleton instance of the class.

    @method current
    @returns {Ember.Object} the instance of the singleton
  **/
  current: function() {
    if (!this._current) {
      this._current = this.create({});
    }

    return this._current;
  },

  /**
    Returns or sets a property on the singleton instance.

    @method currentProp
    @param {String} property the property we want to get or set
    @param {String} value the optional value to set the property to
    @returns the value of the property
  **/
  currentProp: function(property, value) {
    if (typeof(value) !== "undefined") {
      this.current().set(property, value);
      return value;
    } else {
      return this.current().get(property);
    }
  }

});


