import round from "discourse/lib/round";
import computed from 'ember-addons/ember-computed-decorators';
import { ajax } from 'discourse/lib/ajax';
import { OFFSET_SIZE } from 'discourse/plugins/poll/components/poll-voters-number';

export default Em.Component.extend({
  didInsertElement() {
    this._super();
    this._fetchUsers();
  },

  _fetchUsers() {
    if (!this.get('isPublic')) return;
    this.send("fetchUsers", this.get('voterIds').slice(0, OFFSET_SIZE));
  },

  @computed('poll.options', 'poll.options.[]')
  voterIds(options) {
    const voterIds = _.uniq([].concat(...(options.map(option => option.get('voter_ids')))));
    return voterIds;
  },

  @computed("poll.options.@each.{html,votes}")
  totalScore() {
    return _.reduce(this.get("poll.options"), function(total, o) {
      const value = parseInt(o.get("html"), 10),
            votes = parseInt(o.get("votes"), 10);
      return total + value * votes;
    }, 0);
  },

  @computed("totalScore", "poll.voters")
  average() {
    const voters = this.get("poll.voters");
    return voters === 0 ? 0 : round(this.get("totalScore") / voters, -2);
  },

  @computed("average")
  averageRating() {
    return I18n.t("poll.average_rating", { average: this.get("average") });
  },

  actions: {
    fetchUsers(voterIds, defer) {
      const pollVoters = this.get('poll.pollVoters') || [];
      const ids = _.difference(voterIds, pollVoters.map(pollVoter => pollVoter.id));

      if (ids.length > 0) {
        ajax("/polls/voters.json", {
          type: "put",
          data: { options: { default: ids } }
        }).then(result => {
          const voters = result.voters;
          const poll = this.get('poll');

          poll.set('pollVoters', _.uniq(
            pollVoters.concat(voters['default']),
            user => user.id
          ));

          if (defer) defer.resolve();
        }).catch((error) => {
          Ember.Logger.error(error);
          bootbox.alert(I18n.t('poll.error_while_fetching_voters'));
        });
      } else {
        if (defer) defer.resolve();
      }
    }
  }
});
