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
      this._current = this.createCurrent();
    }

    return this._current;
  },


  /**
    How the singleton instance is created. This can be overridden
    with logic for creating (or even returning null) your instance.

    By default it just calls `create` with an empty object.

    @method createCurrent
    @returns {Ember.Object} the instance that will be your singleton
  **/
  createCurrent: function() {
    return this.create({});
  },

  /**
    Returns or sets a property on the singleton instance.

    @method currentProp
    @param {String} property the property we want to get or set
    @param {String} value the optional value to set the property to
    @returns the value of the property
  **/
  currentProp: function(property, value) {
    var instance = this.current();
    if (!instance) { return; }

    if (typeof(value) !== "undefined") {
      instance.set(property, value);
      return value;
    } else {
      return instance.get(property);
    }
  }

});


