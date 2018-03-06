import computed from 'ember-addons/ember-computed-decorators';

// Lists of topics on a user's page.
export default Ember.Controller.extend({
  application: Ember.inject.controller(),

  hideCategory: false,
  showPosters: false,
  newIncoming: [],
  incomingCount: 0,
  channel: null,

  _showFooter: function() {
    this.set("application.showFooter", !this.get("model.canLoadMore"));
  }.observes("model.canLoadMore"),

  @computed('incomingCount')
  hasIncoming(incomingCount) {
    return incomingCount > 0;
  },

  subscribe(channel) {
    this.set('channel', channel);

    this.messageBus.subscribe(channel, data => {
      if (this.get('newIncoming').indexOf(data.topic_id) === -1) {
        this.get('newIncoming').push(data.topic_id);
        this.incrementProperty('incomingCount');
      }
    });
  },

  unsubscribe() {
    this.messageBus.unsubscribe(this.get('channel'));
    this._resetTracking();
  },

  _resetTracking() {
    this.setProperties({
      "newIncoming": [],
      "incomingCount": 0,
      "channel": null,
    });
  },

  actions: {
    loadMore: function() {
      this.get('model').loadMore();
    },

    showInserted() {
      this.get('model').loadBefore(this.get('newIncoming'));
      this._resetTracking();
      return false;
    },
  },

});
