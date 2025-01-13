import { computed } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { fmt } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import RestModel from "discourse/models/rest";
import AdminUser from "admin/models/admin-user";

export default class ApiKey extends RestModel {
  @fmt("truncated_key", "%@ ...") truncatedKey;

  @computed("_user")
  get user() {
    return this._user;
  }

  set user(value) {
    if (value && !(value instanceof AdminUser)) {
      this.set("_user", AdminUser.create(value));
    } else {
      this.set("_user", value);
    }
  }

  @computed("_created_by")
  get createdBy() {
    return this._created_by;
  }

  set created_by(value) {
    if (value && !(value instanceof AdminUser)) {
      this.set("_created_by", AdminUser.create(value));
    } else {
      this.set("_created_by", value);
    }
  }

  @discourseComputed("description")
  shortDescription(description) {
    if (!description || description.length < 40) {
      return description;
    }
    return `${description.substring(0, 40)}...`;
  }

  revoke() {
    return ajax(`${this.basePath}/revoke`, {
      type: "POST",
    }).then((result) => this.setProperties(result.api_key));
  }

  undoRevoke() {
    return ajax(`${this.basePath}/undo-revoke`, {
      type: "POST",
    }).then((result) => this.setProperties(result.api_key));
  }

  createProperties() {
    return this.getProperties("description", "username", "scopes");
  }

  @discourseComputed()
  basePath() {
    return this.store
      .adapterFor("api-key")
      .pathFor(this.store, "api-key", this.id);
  }
}
