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

  @discourseComputed(
    "model.time_read",
    "model.days_visited",
    "model.topics_entered",
    "model.posts_read_count",
    "model.likes_given",
    "model.topic_count",
    "model.post_count",
    "model.likes_received",
    "model.recent_time_read"
  )
  showStats(
    timeRead,
    daysVisited,
    topicsEntered,
    postsRead,
    likesGiven,
    topicCount,
    postCount,
    likesReceived,
    recentTimeRead
  ) {
    return (
      timeRead ||
      daysVisited ||
      topicsEntered ||
      postsRead ||
      likesGiven ||
      topicCount ||
      postCount ||
      likesReceived ||
      recentTimeRead
    );
  },

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
