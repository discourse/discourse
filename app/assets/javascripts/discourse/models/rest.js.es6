import Presence from 'discourse/mixins/presence';

const RestModel = Ember.Object.extend(Presence, {
  update(attrs) {
    const self = this,
          type = this.get('__type');

    const munge = this.__munge;
    return this.store.update(type, this.get('id'), attrs).then(function(result) {
      if (result && result[type]) {
        Object.keys(result).forEach(function(k) {
          attrs[k] = result[k];
        });
      }
      self.setProperties(munge(attrs));
      return result;
    });
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
      Ember.warn('Use `store.createRecord` to create records instead of `.create()`');
      args.store = container.lookup('store:main');
    }

    args.__munge = this.munge;
    return this._super(this.munge(args, args.store));
  }
});

export default RestModel;
