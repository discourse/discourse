import discourseComputed from "discourse-common/utils/decorators";
import { alias } from "@ember/object/computed";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import { durationTiny } from "discourse/lib/formatter";

// should be kept in sync with 'UserSummary::MAX_BADGES'
const MAX_BADGES = 6;

export default Controller.extend({
  userController: inject("user"),
  user: alias("userController.model"),

  @discourseComputed("model.badges.length")
  moreBadges(badgesLength) {
    return badgesLength >= MAX_BADGES;
  },

  @discourseComputed("model.time_read")
  timeRead(timeReadSeconds) {
    return durationTiny(timeReadSeconds);
  },

  @discourseComputed("model.time_read", "model.recent_time_read")
  showRecentTimeRead(timeRead, recentTimeRead) {
    return timeRead !== recentTimeRead && recentTimeRead !== 0;
  },

  @discourseComputed("model.recent_time_read")
  recentTimeRead(recentTimeReadSeconds) {
    return recentTimeReadSeconds > 0
      ? durationTiny(recentTimeReadSeconds)
      : null;
  }
});
