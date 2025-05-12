import Component from "@glimmer/component";
import avatar from "discourse/helpers/avatar";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import { i18n } from "discourse-i18n";

export default class TopicActivityColumn extends Component {
  get topicUser() {
    if (
      moment(this.args.topic.bumped_at).isAfter(this.args.topic.last_posted_at)
    ) {
      return {
        user: undefined,
        username: undefined,
        activityText: "user_updated",
        class: "--updated",
      };
    }

    if (this.args.topic.posts_count > 1) {
      return {
        user: this.args.topic.lastPosterUser,
        username: this.args.topic.last_poster_username,
        activityText: "user_replied",
        class: "--replied",
      };
    } else if (this.args.topic.posts_count === 1) {
      return {
        user: this.args.topic.creator,
        username: this.args.topic.creator.username,
        activityText: "user_posted",
        class: "--posted",
      };
    }
  }

  <template>
    <span class={{concatClass "topic-activity" this.topicUser.class}}>
      <div class="topic-activity__user">
        {{#if this.topicUser.user}}
          {{avatar this.topicUser.user imageSize="small"}}
        {{else}}
          {{icon "pencil"}}
        {{/if}}
      </div>
      {{#if this.topicUser.username}}
        <span
          class="topic-activity__username"
        >{{this.topicUser.username}}</span>
      {{/if}}
      <div class="topic-activity__reason">
        {{i18n (themePrefix this.topicUser.activityText)}}
      </div>
      <div class="topic-activity__time">
        {{formatDate
          @topic.bumpedAt
          leaveAgo="true"
          format="medium-with-ago-and-on"
        }}
      </div>
    </span>
  </template>
}
