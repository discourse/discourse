import Controller, { inject as controller } from "@ember/controller";
import { alias } from "@ember/object/computed";
import discourseComputed from "discourse/lib/decorators";
import { duration } from "discourse/lib/formatter";

// should be kept in sync with 'UserSummary::MAX_BADGES'
const MAX_BADGES = 6;

export default class UserSummaryController extends Controller {
  @controller("user") userController;

  @alias("userController.model") user;

  @discourseComputed("model.badges.length")
  moreBadges(badgesLength) {
    return badgesLength >= MAX_BADGES;
  }

  @discourseComputed("model.time_read")
  timeRead(timeReadSeconds) {
    return duration(timeReadSeconds, { format: "tiny" });
  }

  @discourseComputed("model.time_read")
  timeReadMedium(timeReadSeconds) {
    return duration(timeReadSeconds, { format: "medium" });
  }

  @discourseComputed("model.time_read", "model.recent_time_read")
  showRecentTimeRead(timeRead, recentTimeRead) {
    return timeRead !== recentTimeRead && recentTimeRead !== 0;
  }

  @discourseComputed("model.recent_time_read")
  recentTimeRead(recentTimeReadSeconds) {
    return recentTimeReadSeconds > 0
      ? duration(recentTimeReadSeconds, { format: "tiny" })
      : null;
  }

  @discourseComputed("model.recent_time_read")
  recentTimeReadMedium(recentTimeReadSeconds) {
    return recentTimeReadSeconds > 0
      ? duration(recentTimeReadSeconds, { format: "medium" })
      : null;
  }
}
