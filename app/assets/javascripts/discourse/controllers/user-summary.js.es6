import Controller from "@ember/controller";
import computed from "ember-addons/ember-computed-decorators";
import { durationTiny } from "discourse/lib/formatter";

// should be kept in sync with 'UserSummary::MAX_BADGES'
const MAX_BADGES = 6;

export default Controller.extend({
  userController: Ember.inject.controller("user"),
  user: Ember.computed.alias("userController.model"),

  @computed("model.badges.length")
  moreBadges(badgesLength) {
    return badgesLength >= MAX_BADGES;
  },

  @computed("model.time_read")
  timeRead(timeReadSeconds) {
    return durationTiny(timeReadSeconds);
  },

  @computed("model.time_read", "model.recent_time_read")
  showRecentTimeRead(timeRead, recentTimeRead) {
    return timeRead !== recentTimeRead && recentTimeRead !== 0;
  },

  @computed("model.recent_time_read")
  recentTimeRead(recentTimeReadSeconds) {
    return recentTimeReadSeconds > 0
      ? durationTiny(recentTimeReadSeconds)
      : null;
  }
});
