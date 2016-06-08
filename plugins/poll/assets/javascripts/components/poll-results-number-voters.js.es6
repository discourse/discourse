import computed from 'ember-addons/ember-computed-decorators';
import User from 'discourse/models/user';
import PollVoters from 'discourse/plugins/poll/components/poll-voters';

export default PollVoters.extend({
  @computed("pollsVoters", "poll.options", "showMore", "isExpanded", "numOfVotersToShow")
  users(pollsVoters, options, showMore, isExpanded, numOfVotersToShow) {
    var users = [];
    var voterIds = [];
    const shouldLimit = showMore && !isExpanded;

    options.forEach(option => {
      option.voter_ids.forEach(voterId => {
        if (shouldLimit) {
          if (!(users.length > numOfVotersToShow - 1)) {
            users.push(pollsVoters[voterId]);
          }
        } else {
          users.push(pollsVoters[voterId]);
        }
      })
    });

    return users;
  },

  @computed("pollsVoters", "numOfVotersToShow")
  showMore(pollsVoters, numOfVotersToShow) {
    return !(Object.keys(pollsVoters).length < numOfVotersToShow);
  }
});
