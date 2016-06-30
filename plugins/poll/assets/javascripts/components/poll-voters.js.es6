import { ajax } from 'discourse/lib/ajax';
export default Ember.Component.extend({
  layoutName: "components/poll-voters",
  tagName: 'ul',
  classNames: ["poll-voters-list"],
  isExpanded: false,
  numOfVotersToShow: 0,
  offset: 0,
  loading: false,
  pollsVoters: null,

  init() {
    this._super();
    this.set("pollsVoters", []);
  },

  _fetchUsers() {
    this.set("loading", true);

    ajax("/polls/voters.json", {
      type: "get",
      data: { user_ids: this.get("voterIds") }
    }).then(result => {
      if (this.isDestroyed) return;
      this.set("pollsVoters", this.get("pollsVoters").concat(result.users));
      this.incrementProperty("offset");
      this.set("loading", false);
    }).catch((error) => {
      Ember.logger.log(error);
      bootbox.alert(I18n.t('poll.error_while_fetching_voters'));
    });
  },

  _getIds(ids) {
    const numOfVotersToShow = this.get("numOfVotersToShow");
    const offset = this.get("offset");
    return ids.slice(numOfVotersToShow * offset, numOfVotersToShow * (offset + 1));
  },

  didInsertElement() {
    this._super();

    Ember.run.schedule("afterRender", () => {
      this.set("numOfVotersToShow", Math.round(this.$().width() / 25) * 2);
      if (this.get("voterIds").length > 0) this._fetchUsers();
    });
  },

  actions: {
    loadMore() {
      this._fetchUsers();
    }
  }
});
