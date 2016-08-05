import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  layoutName: "components/poll-voters",
  classNames: ["poll-voters"],
  offset: 1,
  loading: false,
  voters: Ember.computed.alias('option.voters'),

  @computed('option.votes', 'option.voters')
  canLoadMore(votes, voters) {
    return (!voters) ? false : voters.length < votes;
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
      const ids = this.get('option.voter_ids');
      const optionVoterIds = {};
      optionVoterIds[this.get('option.id')] = ids.slice(20 * offset, 20 * (offset + 1));

      this.sendAction('fetch', optionVoterIds, defer);
    }
  }
});
