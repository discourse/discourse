import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import element from "discourse/helpers/element";
import number from "discourse/helpers/number";
import I18n from "discourse-i18n";

export default class RepliesCell extends Component {
  @service siteSettings;

  get ratio() {
    const likes = parseFloat(this.args.topic.like_count);
    const posts = parseFloat(this.args.topic.posts_count);

    if (posts < 10) {
      return 0;
    }

    return (likes || 0) / posts;
  }

  get title() {
    return I18n.messageFormat("posts_likes_MF", {
      count: this.args.topic.replyCount,
      ratio: this.ratioText,
    }).trim();
  }

  get ratioText() {
    if (this.ratio > this.siteSettings.topic_post_like_heat_high) {
      return "high";
    }
    if (this.ratio > this.siteSettings.topic_post_like_heat_medium) {
      return "med";
    }
    if (this.ratio > this.siteSettings.topic_post_like_heat_low) {
      return "low";
    }
    return "";
  }

  get likesHeat() {
    if (this.ratioText?.length) {
      return `heatmap-${this.ratioText}`;
    }
  }

  get wrapperElement() {
    return element(this.args.tagName ?? "td");
  }

  <template>
    <this.wrapperElement
      class="num posts-map posts {{this.likesHeat}} topic-list-data"
    >
      <a href={{@topic.firstPostUrl}} class="badge-posts">
        <PluginOutlet
          @name="topic-list-before-reply-count"
          @outletArgs={{hash topic=@topic}}
        />
        {{number @topic.replyCount noTitle="true"}}
      </a>
    </this.wrapperElement>
  </template>
}
