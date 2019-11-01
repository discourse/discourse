import { equal } from "@ember/object/computed";
import EmberObject from "@ember/object";

const RestModel = EmberObject.extend({
  isNew: equal("__state", "new"),
  isCreated: equal("__state", "created"),
  isSaving: false,

  beforeCreate() {},
  afterUpdate() {},

  update(props) {
    if (this.isSaving) {
      return Ember.RSVP.reject();
    }

    props = props || this.updateProperties();

    this.set("isSaving", true);
    return this.store
      .update(this.__type, this.id, props)
      .then(res => {
        const payload = this.__munge(res.payload || res.responseJson);

        if (payload.success === "OK") {
          Ember.warn("An update call should return the updated attributes", {
            id: "discourse.rest-model.update-attributes"
          });
          res = props;
        }

        this.setProperties(payload);
        this.afterUpdate(res);
        res.target = this;
        return res;
      })
      .finally(() => this.set("isSaving", false));
  },

  _saveNew(props) {
    if (this.isSaving) {
      return Ember.RSVP.reject();
    }

    props = props || this.createProperties();

    this.beforeCreate(props);

    const adapter = this.store.adapterFor(this.__type);

    this.set("isSaving", true);
    return adapter
      .createRecord(this.store, this.__type, props)
      .then(res => {
        if (!res) {
          throw new Error("Received no data back from createRecord");
        }

        // We can get a response back without properties, for example
        // when a post is queued.
        if (res.payload) {
          this.setProperties(this.__munge(res.payload));
          this.set("__state", "created");
        }

        res.target = this;
        return res;
      })
      .finally(() => this.set("isSaving", false));
  },

  createProperties() {
    throw new Error(
      "You must overwrite `createProperties()` before saving a record"
    );
  },

  save(props) {
    return this.isNew ? this._saveNew(props) : this.update(props);
  },

  destroyRecord() {
    return this.store.destroyRecord(this.__type, this);
  }
});

RestModel.reopenClass({
  // Overwrite and JSON will be passed through here before `create` and `update`
  munge(json) {
    return json;
  },

  create(args) {
    args = args || {};
    if (!args.store) {
      const container = Discourse.__container__;
      args.store = container.lookup("service:store");
    }

    args.__munge = this.munge;
    return this._super(this.munge(args, args.store));
  }
});

export default RestModel;
