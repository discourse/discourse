import computed from 'ember-addons/ember-computed-decorators';

// should be kept in sync with 'UserSummary::MAX_SUMMARY_RESULTS'
const MAX_SUMMARY_RESULTS = 6;
// should be kept in sync with 'UserSummary::MAX_BADGES'
const MAX_BADGES = 6;

export default Ember.Controller.extend({
  needs: ['user'],
  user: Ember.computed.alias('controllers.user.model'),

  @computed("model.topics.length")
  moreTopics(topicsLength) { return topicsLength >= MAX_SUMMARY_RESULTS; },

  @computed("model.replies.length")
  moreReplies(repliesLength) { return repliesLength >= MAX_SUMMARY_RESULTS; },

  @computed("model.badges.length")
  moreBadges(badgesLength) { return badgesLength >= MAX_BADGES; },
});
