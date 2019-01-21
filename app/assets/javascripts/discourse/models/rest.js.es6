const RestModel = Ember.Object.extend({
  isNew: Ember.computed.equal("__state", "new"),
  isCreated: Ember.computed.equal("__state", "created"),
  isSaving: false,

  beforeCreate() {},
  afterUpdate() {},

  update(props) {
    if (this.get("isSaving")) {
      return Ember.RSVP.reject();
    }

    props = props || this.updateProperties();

    const type = this.get("__type"),
      store = this.get("store");

    const self = this;
    self.set("isSaving", true);
    return store
      .update(type, this.get("id"), props)
      .then(function(res) {
        const payload = self.__munge(res.payload || res.responseJson);

        if (payload.success === "OK") {
          Ember.warn("An update call should return the updated attributes", {
            id: "discourse.rest-model.update-attributes"
          });
          res = props;
        }

        self.setProperties(payload);
        self.afterUpdate(res);
        res.target = self;
        return res;
      })
      .finally(() => this.set("isSaving", false));
  },

  _saveNew(props) {
    if (this.get("isSaving")) {
      return Ember.RSVP.reject();
    }

    props = props || this.createProperties();

    this.beforeCreate(props);

    const type = this.get("__type"),
      store = this.get("store"),
      adapter = store.adapterFor(type);

    const self = this;
    self.set("isSaving", true);
    return adapter
      .createRecord(store, type, props)
      .then(function(res) {
        if (!res) {
          throw new Error("Received no data back from createRecord");
        }

        // We can get a response back without properties, for example
        // when a post is queued.
        if (res.payload) {
          self.setProperties(self.__munge(res.payload));
          self.set("__state", "created");
        }

        res.target = self;
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
    return this.get("isNew") ? this._saveNew(props) : this.update(props);
  },

  destroyRecord() {
    const type = this.get("__type");
    return this.store.destroyRecord(type, this);
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
