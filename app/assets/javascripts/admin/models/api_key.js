/**
  Our data model for representing an API key in the system

  @class ApiKey
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.ApiKey = Discourse.Model.extend({

  /**
    Regenerates the api key

    @method regenerate
    @returns {Promise} a promise that resolves to the key
  **/
  regenerate: function() {
    var self = this;
    return Discourse.ajax('/admin/api/key', {type: 'PUT', data: {id: this.get('id')}}).then(function (result) {
      self.set('key', result.api_key.key);
      return self;
    });
  },

  /**
    Revokes the current key

    @method revoke
    @returns {Promise} a promise that resolves when the key has been revoked
  **/
  revoke: function() {
    var self = this;
    return Discourse.ajax('/admin/api/key', {type: 'DELETE', data: {id: this.get('id')}});
  }

});

Discourse.ApiKey.reopenClass({

  /**
    Creates an API key instance with internal user object

    @method create
    @param {Object} the properties to create
    @returns {Discourse.ApiKey} the ApiKey instance
  **/
  create: function() {
    var result = this._super.apply(this, arguments);
    if (result.user) {
      result.user = Discourse.AdminUser.create(result.user);
    }
    return result;
  },

  /**
    Finds a list of API keys

    @method find
    @returns {Promise} a promise that resolves to the array of `Discourse.ApiKey` instances
  **/
  find: function() {
    return Discourse.ajax("/admin/api").then(function(keys) {
      return keys.map(function (key) {
        return Discourse.ApiKey.create(key);
      });
    });
  },

  /**
    Generates a master api key and returns it.

    @method generateMasterKey
    @returns {Promise} a promise that resolves to a master `Discourse.ApiKey`
  **/
  generateMasterKey: function() {
    return Discourse.ajax("/admin/api/key", {type: 'POST'}).then(function (result) {
      return Discourse.ApiKey.create(result.api_key);
    });
  }

});
