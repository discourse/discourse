import Presence from 'discourse/mixins/presence';

const RestModel = Ember.Object.extend(Presence, {
  isNew: Ember.computed.equal('__state', 'new'),
  isCreated: Ember.computed.equal('__state', 'created'),

  afterUpdate: Ember.K,

  update(props) {
    props = props || this.updateProperties();

    const type = this.get('__type'),
          store = this.get('store');

    const self = this;
    return store.update(type, this.get('id'), props).then(function(res) {
      self.setProperties(self.__munge(res.payload || res.responseJson));
      self.afterUpdate(res);
      return res;
    });
  },

  _saveNew(props) {
    props = props || this.createProperties();

    const type = this.get('__type'),
          store = this.get('store'),
          adapter = store.adapterFor(type);

    const self = this;
    return adapter.createRecord(store, type, props).then(function(res) {
      if (!res) { throw "Received no data back from createRecord"; }

      // We can get a response back without properties, for example
      // when a post is queued.
      if (res.payload) {
        self.setProperties(self.__munge(res.payload));
        self.set('__state', 'created');
      }

      res.target = self;
      return res;
    });
  },

  createProperties() {
    throw "You must overwrite `createProperties()` before saving a record";
  },

  save(props) {
    return this.get('isNew') ? this._saveNew(props) : this.update(props);
  },

  destroyRecord() {
    const type = this.get('__type');
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
      // Ember.warn('Use `store.createRecord` to create records instead of `.create()`');
      args.store = container.lookup('store:main');
    }

    args.__munge = this.munge;
    return this._super(this.munge(args, args.store));
  }
});

export default RestModel;
