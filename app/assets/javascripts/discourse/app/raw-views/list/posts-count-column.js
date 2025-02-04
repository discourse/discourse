import EmberObject from "@ember/object";
import discourseComputed from "discourse/lib/decorators";
import I18n from "discourse-i18n";

export default class PostsCountColumn extends EmberObject {
  tagName = "td";

  @discourseComputed("topic.like_count", "topic.posts_count")
  ratio(likeCount, postCount) {
    const likes = parseFloat(likeCount);
    const posts = parseFloat(postCount);

    if (posts < 10) {
      return 0;
    }

    return (likes || 0) / posts;
  }

  @discourseComputed("topic.replyCount", "ratioText")
  title(count, ratio) {
    return I18n.messageFormat("posts_likes_MF", {
      count,
      ratio,
    });
  }

  @discourseComputed("ratio")
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
  }

  @discourseComputed("ratioText")
  likesHeat(ratioText) {
    if (ratioText && ratioText.length) {
      return `heatmap-${ratioText}`;
    }
  }
}
