import computed from 'ember-addons/ember-computed-decorators';
import User from 'discourse/models/user';
import PollVoters from 'discourse/plugins/poll/components/poll-voters';

export default PollVoters.extend({
  @computed("pollsVoters", "option.voter_ids", "showMore", "isExpanded", "numOfVotersToShow")
  users(pollsVoters, voterIds, showMore, isExpanded, numOfVotersToShow) {
    var users = [];

    if (showMore && !isExpanded) {
      voterIds = voterIds.slice(0, numOfVotersToShow);
    }

    voterIds.forEach(voterId => {
      users.push(pollsVoters[voterId]);
    });

    return users;
  },

  @computed("option.votes", "numOfVotersToShow")
  showMore(numOfVotes, numOfVotersToShow) {
    return !(numOfVotes < numOfVotersToShow);
  }
});
