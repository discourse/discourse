/**
  A base object we can use to handle models in the Discourse client application.

  @class Model
  @extends Ember.Object
  @uses Discourse.Presence
  @namespace Discourse
  @module Discourse
**/
Discourse.Model = Ember.Object.extend(Discourse.Presence, {

  /**
    Update our object from another object

    @method mergeAttributes
    @param {Object} attrs The attributes we want to merge with
  **/
  mergeAttributes: function(attrs) {
    var _this = this;
    _.each(attrs, function(v,k) {
      _this.set(k, v);
    });
  }

});

Discourse.Model.reopenClass({

  /**
    Given an array of values, return them in a hash

    @method extractByKey
    @param {Object} collection The collection of values
    @param {Object} klass Optional The class to instantiate
  **/
  extractByKey: function(collection, klass) {
    var retval = {};
    if (!collection) return retval;
    _.each(collection,function(c) {
      retval[c.id] = klass.create(c);
    });
    return retval;
  }
});


