import Component from "@glimmer/component";
import concatClass from "discourse/helpers/concat-class";
import formatDate from "discourse/helpers/format-date";

export default class TopicActivityColumn extends Component {
  get topicUser() {
    if (
      moment(this.args.topic.bumped_at).isAfter(this.args.topic.last_posted_at)
    ) {
      return {
        user: undefined,
        username: undefined,
        class: "--updated",
      };
    }

    if (this.args.topic.posts_count > 1) {
      return {
        user: this.args.topic.lastPosterUser,
        username: this.args.topic.last_poster_username,
        class: "--replied",
      };
    } else if (this.args.topic.posts_count === 1) {
      return {
        user: this.args.topic.firstPosterUser,
        username: this.args.topic.last_poster_username,
        class: "--created",
      };
    } else {
      return;
    }
  }

  <template>
    <span class={{concatClass "topic-activity" this.topicUser.class}}>
      {{#if this.topicUser.username}}
        <span
          class="topic-activity__username"
        >{{this.topicUser.username}}</span>
        <span class="dot-separator"></span>
      {{/if}}
      <div class="topic-activity__time">
        {{formatDate @topic.bumpedAt leaveAgo="true" format="tiny"}}
      </div>
    </span>
  </template>
}
