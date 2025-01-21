import { tracked } from "@glimmer/tracking";
import { warn } from "@ember/debug";
import EmberObject from "@ember/object";
import { equal } from "@ember/object/computed";
import { getOwner, setOwner } from "@ember/owner";
import { Promise } from "rsvp";
import { getOwnerWithFallback } from "discourse/lib/get-owner";

export default class RestModel extends EmberObject {
  // Overwrite and JSON will be passed through here before `create` and `update`
  static munge(json) {
    return json;
  }

  static create(args) {
    args = args || {};

    args.__munge = this.munge;
    const createArgs = this.munge(args, args.store);

    // Some Discourse code calls `model.create()` directly without going through the
    // store. In that case the owner is not set, and injections will fail. This workaround ensures
    // the owner is always present. Eventually we should use the store for everything to fix this.
    const receivedOwner = getOwner(createArgs);
    if (!receivedOwner || receivedOwner.isDestroyed) {
      setOwner(createArgs, getOwnerWithFallback());
    }

    return super.create(createArgs);
  }

  @tracked isSaving = false;
  @equal("__state", "new") isNew;
  @equal("__state", "created") isCreated;

  beforeCreate() {}
  afterCreate() {}

  beforeUpdate() {}
  afterUpdate() {}

  update(props) {
    if (this.isSaving) {
      return Promise.reject();
    }

    props = props || this.updateProperties();

    this.beforeUpdate(props);

    this.set("isSaving", true);
    return this.store
      .update(this.__type, this.id, props)
      .then((res) => {
        const payload = this.__munge(res.payload || res.responseJson);

        if (payload.success === "OK") {
          warn("An update call should return the updated attributes", {
            id: "discourse.rest-model.update-attributes",
          });
          res = props;
        }

        this.setProperties(payload);
        this.afterUpdate(res);
        res.target = this;
        return res;
      })
      .finally(() => this.set("isSaving", false));
  }

  _saveNew(props) {
    if (this.isSaving) {
      return Promise.reject();
    }

    props = props || this.createProperties();

    this.beforeCreate(props);

    const adapter = this.store.adapterFor(this.__type);

    this.set("isSaving", true);
    return adapter
      .createRecord(this.store, this.__type, props)
      .then((res) => {
        if (!res) {
          throw new Error("Received no data back from createRecord");
        }

        // We can get a response back without properties, for example
        // when a post is queued.
        if (res.payload) {
          this.setProperties(this.__munge(res.payload));
          this.set("__state", "created");
        }

        this.afterCreate(res);
        res.target = this;
        return res;
      })
      .finally(() => this.set("isSaving", false));
  }

  createProperties() {
    throw new Error(
      "You must overwrite `createProperties()` before saving a record"
    );
  }

  save(props) {
    return this.isNew ? this._saveNew(props) : this.update(props);
  }

  destroyRecord() {
    return this.store.destroyRecord(this.__type, this);
  }
}
