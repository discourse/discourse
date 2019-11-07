import AdminUser from "admin/models/admin-user";
import RestModel from "discourse/models/rest";
import { ajax } from "discourse/lib/ajax";
import computed from "ember-addons/ember-computed-decorators";

const ApiKey = RestModel.extend({
  user: Ember.computed("_user", {
    get() {
      return this._user;
    },
    set(key, value) {
      if (value && !(value instanceof AdminUser)) {
        this.set("_user", AdminUser.create(value));
      } else {
        this.set("_user", value);
      }
      return this._user;
    }
  }),

  @computed("key")
  shortKey(key) {
    return `${key.substring(0, 4)}...`;
  },

  @computed("description")
  shortDescription(description) {
    if (!description || description.length < 40) return description;
    return `${description.substring(0, 40)}...`;
  },

  revoke() {
    return ajax(`${this.basePath}/revoke`, {
      type: "POST"
    }).then(result => this.setProperties(result.api_key));
  },

  undoRevoke() {
    return ajax(`${this.basePath}/undo-revoke`, {
      type: "POST"
    }).then(result => this.setProperties(result.api_key));
  },

  createProperties() {
    return this.getProperties("description", "username");
  },

  @computed()
  basePath() {
    return this.store
      .adapterFor("api-key")
      .pathFor(this.store, "api-key", this.id);
  }
});

export default ApiKey;
