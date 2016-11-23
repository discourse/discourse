import computed from 'ember-addons/ember-computed-decorators';

export const OFFSET_SIZE = 20;

export default Ember.Component.extend({
  layoutName: "components/poll-voters",
  classNames: ["poll-voters"],
  loading: false,
  voters: Ember.computed.alias('poll.pollVoters'),

  @computed('poll.voters')
  offset(voters) {
    return voters > OFFSET_SIZE ? 1 : 0;
  },

  @computed('poll.voters', 'poll.pollVoters')
  canLoadMore(voters, pollVoters) {
    return (!pollVoters) ? false : pollVoters.length < voters;
  },

  actions: {
    loadMore() {
      this.set('loading', true);
      const offset = this.get('offset');

      const voterIds = this.get('voterIds').slice(
        OFFSET_SIZE * offset,
        OFFSET_SIZE * (offset + 1)
      );

      const defer = Em.RSVP.defer();

      defer.promise.then(() => {
        this.set('loading', false);
        if (voterIds.length === OFFSET_SIZE)  this.incrementProperty('offset');
      });

      this.sendAction('fetch', voterIds, defer);
    }
  }
});
