import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  layoutName: "components/poll-voters",
  classNames: ["poll-voters"],
  offset: 1,
  loading: false,
  voters: Ember.computed.alias('poll.pollVoters'),

  @computed('poll.voters', 'poll.pollVoters')
  canLoadMore(voters, pollVoters) {
    return (!pollVoters) ? false : pollVoters.length < voters;
  },

  actions: {
    loadMore() {
      this.set('loading', true);
      const defer = Em.RSVP.defer();

      defer.promise.then(() => {
        this.set('loading', false);
        this.incrementProperty('offset');
      });

      const offset = this.get('offset');
      this.sendAction('fetch', this.get('voterIds').slice(20 * offset, 20 * (offset + 1)), defer);
    }
  }
});
