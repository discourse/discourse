import computed from "ember-addons/ember-computed-decorators";
import { fmt } from "discourse/lib/computed";

export default Ember.Object.extend({
  tagName: "td",

  @computed("topic.like_count", "topic.posts_count")
  ratio(likeCount, postCount) {
    const likes = parseFloat(likeCount);
    const posts = parseFloat(postCount);

    if (posts < 10) {
      return 0;
    }

    return (likes || 0) / posts;
  },

  @computed("topic.replyCount", "ratioText")
  title(count, ratio) {
    return I18n.messageFormat("posts_likes_MF", { count, ratio }).trim();
  },

  @computed("ratio")
  ratioText(ratio) {
    const settings = this.siteSettings;
    if (ratio > settings.topic_post_like_heat_high) {
      return "high";
    }
    if (ratio > settings.topic_post_like_heat_medium) {
      return "med";
    }
    if (ratio > settings.topic_post_like_heat_low) {
      return "low";
    }
    return "";
  },

  likesHeat: fmt("ratioText", "heatmap-%@")
});
