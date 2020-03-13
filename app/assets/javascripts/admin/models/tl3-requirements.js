import discourseComputed from "discourse-common/utils/decorators";
import EmberObject from "@ember/object";

export default EmberObject.extend({
  @discourseComputed("days_visited", "time_period")
  days_visited_percent(daysVisited, timePeriod) {
    return Math.round((daysVisited * 100) / timePeriod);
  },

  @discourseComputed("min_days_visited", "time_period")
  min_days_visited_percent(minDaysVisited, timePeriod) {
    return Math.round((minDaysVisited * 100) / timePeriod);
  },

  @discourseComputed(
    "days_visited",
    "min_days_visited",
    "num_topics_replied_to",
    "min_topics_replied_to",
    "topics_viewed",
    "min_topics_viewed",
    "posts_read",
    "min_posts_read",
    "num_flagged_posts",
    "max_flagged_posts",
    "topics_viewed_all_time",
    "min_topics_viewed_all_time",
    "posts_read_all_time",
    "min_posts_read_all_time",
    "num_flagged_by_users",
    "max_flagged_by_users",
    "num_likes_given",
    "min_likes_given",
    "num_likes_received",
    "min_likes_received",
    "num_likes_received",
    "min_likes_received",
    "num_likes_received_days",
    "min_likes_received_days",
    "num_likes_received_users",
    "min_likes_received_users",
    "trust_level_locked",
    "penalty_counts.silenced",
    "penalty_counts.suspended"
  )
  met() {
    return {
      days_visited: this.days_visited >= this.min_days_visited,
      topics_replied_to:
        this.num_topics_replied_to >= this.min_topics_replied_to,
      topics_viewed: this.topics_viewed >= this.min_topics_viewed,
      posts_read: this.posts_read >= this.min_posts_read,
      topics_viewed_all_time:
        this.topics_viewed_all_time >= this.min_topics_viewed_all_time,
      posts_read_all_time:
        this.posts_read_all_time >= this.min_posts_read_all_time,
      flagged_posts: this.num_flagged_posts <= this.max_flagged_posts,
      flagged_by_users: this.num_flagged_by_users <= this.max_flagged_by_users,
      likes_given: this.num_likes_given >= this.min_likes_given,
      likes_received: this.num_likes_received >= this.min_likes_received,
      likes_received_days:
        this.num_likes_received_days >= this.min_likes_received_days,
      likes_received_users:
        this.num_likes_received_users >= this.min_likes_received_users,
      level_locked: this.trust_level_locked,
      silenced: this.get("penalty_counts.silenced") === 0,
      suspended: this.get("penalty_counts.suspended") === 0
    };
  }
});
