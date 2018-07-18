import AdminUser from "admin/models/admin-user";
import { ajax } from "discourse/lib/ajax";

const ApiKey = Discourse.Model.extend({
  /**
    Regenerates the api key

    @method regenerate
    @returns {Promise} a promise that resolves to the key
  **/
  regenerate: function() {
    var self = this;
    return ajax("/admin/api/key", {
      type: "PUT",
      data: { id: this.get("id") }
    }).then(function(result) {
      self.set("key", result.api_key.key);
      return self;
    });
  },

  /**
    Revokes the current key

    @method revoke
    @returns {Promise} a promise that resolves when the key has been revoked
  **/
  revoke: function() {
    return ajax("/admin/api/key", {
      type: "DELETE",
      data: { id: this.get("id") }
    });
  }
});

ApiKey.reopenClass({
  /**
    Creates an API key instance with internal user object

    @method create
    @param {...} var_args the properties to initialize this with
    @returns {ApiKey} the ApiKey instance
  **/
  create() {
    var result = this._super.apply(this, arguments);
    if (result.user) {
      result.user = AdminUser.create(result.user);
    }
    return result;
  },

  /**
    Finds a list of API keys

    @method find
    @returns {Promise} a promise that resolves to the array of `ApiKey` instances
  **/
  find: function() {
    return ajax("/admin/api/keys").then(function(keys) {
      return keys.map(function(key) {
        return ApiKey.create(key);
      });
    });
  },

  /**
    Generates a master api key and returns it.

    @method generateMasterKey
    @returns {Promise} a promise that resolves to a master `ApiKey`
  **/
  generateMasterKey: function() {
    return ajax("/admin/api/key", { type: "POST" }).then(function(result) {
      return ApiKey.create(result.api_key);
    });
  }
});

export default ApiKey;
