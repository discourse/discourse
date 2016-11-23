import evenRound from "discourse/plugins/poll/lib/even-round";
import { default as computed, observes } from "ember-addons/ember-computed-decorators";
import { ajax } from 'discourse/lib/ajax';

export default Em.Component.extend({
  tagName: "ul",
  classNames: ["results"],

  didInsertElement() {
    this._super();
    this._fetchUsers();
  },

  _fetchUsers() {
    if (!this.get('isPublic')) return;
    this.send("fetchUsers", this.get('optionsVoterIds'));
  },

  @observes('isPublic', 'poll.options.[]')
  updateNewVoters(isPublic) {
    if (!isPublic) return;
    this._fetchUsers();
  },

  @computed('options', 'poll.options.[]')
  optionsVoterIds(options) {
    const ids = {};

    options.forEach(option => {
      ids[option.get('id')] = option.get('voter_ids').slice(0, 20);
    });

    return ids;
  },

  @computed("poll.voters", "poll.type", "poll.options.[]")
  options(voters, type) {
    const options = this.get("poll.options").slice(0).sort((a, b) => {
      return b.get("votes") - a.get("votes");
    });

    let percentages = voters === 0 ?
      Array(options.length).fill(0) :
      _.map(options, o => 100 * o.get("votes") / voters);

    // properly round percentages
    if (type === "multiple") {
      // when the poll is multiple choices, just "round down"
      percentages = percentages.map(p => Math.floor(p));
    } else {
      // when the poll is single choice, adds up to 100%
      percentages = evenRound(percentages);
    }

    options.forEach((option, i) => {
      const percentage = percentages[i];
      const style = new Handlebars.SafeString(`width: ${percentage}%`);

      option.setProperties({
        percentage,
        style,
        title: I18n.t("poll.option_title", { count: option.get("votes") }),
      });
    });

    return options;
  },

  actions: {
    fetchUsers(optionsVoterIds, defer) {
      const ids = {};
      let updated = false;

      this.get('options').forEach(option => {
        const optionId = option.get('id');
        const newIds = optionsVoterIds[optionId];
        const oldIds = (option.get('voters') || []).map(user => user.id);
        const diffIds = _.difference(newIds, oldIds);

        if (diffIds.length > 0) {
          ids[optionId] = diffIds;
          updated = true;
        }
      });

      if (updated) {
        ajax("/polls/voters.json", {
          type: "put",
          data: { options: ids }
        }).then(result => {
          const voters = result.voters;

          this.get('options').forEach(option => {
            const optionVoters = voters[option.get('id')];

            if (!optionVoters) return;

            option.set('voters', _.uniq(
              (option.get('voters') || []).concat(optionVoters),
              user => user.id
            ));

            if (defer) defer.resolve();
          });
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
