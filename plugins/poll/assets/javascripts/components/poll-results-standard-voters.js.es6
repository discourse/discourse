import computed from 'ember-addons/ember-computed-decorators';
import PollVoters from 'discourse/plugins/poll/components/poll-voters';

export default PollVoters.extend({
  @computed("option.votes", "pollsVoters")
  canLoadMore(voters, pollsVoters) {
    return pollsVoters.length < voters;
  },

  @computed("option.voter_ids", "offset")
  voterIds(ids) {
    return this._getIds(ids);
  }
});
