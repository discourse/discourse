import AdminUser from "admin/models/admin-user";
import { ajax } from "discourse/lib/ajax";

const KEY_ENDPOINT = "/admin/api/key";
const KEYS_ENDPOINT = "/admin/api/keys";

const ApiKey = Discourse.Model.extend({
  regenerate() {
    return ajax(KEY_ENDPOINT, {
      type: "PUT",
      data: { id: this.get("id") }
    }).then(result => {
      this.set("key", result.api_key.key);
      return this;
    });
  },

  revoke() {
    return ajax(KEY_ENDPOINT, {
      type: "DELETE",
      data: { id: this.get("id") }
    });
  }
});

ApiKey.reopenClass({
  create() {
    const result = this._super.apply(this, arguments);
    if (result.user) {
      result.user = AdminUser.create(result.user);
    }
    return result;
  },

  find() {
    return ajax(KEYS_ENDPOINT).then(keys =>
      keys.map(key => ApiKey.create(key))
    );
  },

  generateMasterKey() {
    return ajax(KEY_ENDPOINT, { type: "POST" }).then(result =>
      ApiKey.create(result.api_key)
    );
  }
});

export default ApiKey;
