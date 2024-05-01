import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import number from "discourse/helpers/number";
import DiscourseURL from "discourse/lib/url";
import icon from "discourse-common/helpers/d-icon";
import I18n from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

function entranceDate(dt, showTime) {
  const today = new Date();

  if (dt.toDateString() === today.toDateString()) {
    return moment(dt).format(I18n.t("dates.time"));
  }

  if (dt.getYear() === today.getYear()) {
    // No year
    return moment(dt).format(
      showTime
        ? I18n.t("dates.long_date_without_year_with_linebreak")
        : I18n.t("dates.long_no_year_no_time")
    );
  }

  return moment(dt).format(
    showTime
      ? I18n.t("dates.long_date_with_year_with_linebreak")
      : I18n.t("dates.long_date_with_year_without_time")
  );
}

export default class PostsCountColumn extends Component {
  @service historyStore;
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
    if (!this.args.tagName) {
      return <template><td ...attributes>{{yield}}</td></template>;
    } else if (this.args.tagName === "div") {
      return <template><div ...attributes>{{yield}}</div></template>;
    } else {
      throw new Error("Unsupported posts-count-column @tagName");
    }
  }

  get createdDate() {
    return new Date(this.args.topic.created_at);
  }

  get bumpedDate() {
    return new Date(this.args.topic.bumped_at);
  }

  get showTime() {
    return (
      this.bumpedDate.getTime() - this.createdDate.getTime() <
      1000 * 60 * 60 * 24 * 2
    );
  }

  get topDate() {
    return entranceDate(this.createdDate, this.showTime);
  }

  get bottomDate() {
    return entranceDate(this.bumpedDate, this.showTime);
  }

  @action
  jumpTo(destination) {
    this.historyStore.set("lastTopicIdViewed", this.args.topic.id);
    DiscourseURL.routeTo(destination);
  }

  <template>
    <this.wrapperElement
      class="num posts-map posts {{this.likesHeat}} topic-list-data"
    >
      <DMenu
        @ariaLabel={{this.title}}
        @placement="center"
        @autofocus={{true}}
        @triggerClass="btn-link posts-map badge-posts {{this.likesHeat}}"
      >
        <:trigger>
          <PluginOutlet @name="topic-list-before-reply-count" />
          {{number @topic.replyCount noTitle="true"}}
        </:trigger>

        <:content>
          <div id="topic-entrance" class="--glimmer">
            <button
              {{on "click" (fn this.jumpTo @topic.url)}}
              aria-label="topic_entrance.sr_jump_top_button"
              class="btn btn-default full jump-top"
            >
              {{icon "step-backward"}}
              {{htmlSafe this.topDate}}
            </button>

            <button
              {{on "click" (fn this.jumpTo @topic.lastPostUrl)}}
              aria-label="topic_entrance.sr_jump_bottom_button"
              class="btn btn-default full jump-bottom"
            >
              {{htmlSafe this.bottomDate}}
              {{icon "step-forward"}}
            </button>
          </div>
        </:content>
      </DMenu>
    </this.wrapperElement>
  </template>
}
