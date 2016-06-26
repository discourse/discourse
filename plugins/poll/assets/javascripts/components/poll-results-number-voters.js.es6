import computed from 'ember-addons/ember-computed-decorators';
import PollVoters from 'discourse/plugins/poll/components/poll-voters';

export default PollVoters.extend({
  @computed("poll.voters", "pollsVoters")
  canLoadMore(voters, pollsVoters) {
    return pollsVoters.length < voters;
  },

  @computed("poll.options", "offset")
  voterIds(options) {
    const ids = [].concat(...(options.map(option => option.voter_ids)));
    return this._getIds(ids);
  }
});
