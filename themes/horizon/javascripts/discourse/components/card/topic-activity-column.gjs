import Component from "@glimmer/component";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";

export default class TopicActivityColumn extends Component {
  get topicUser() {
    const bumpedLastPostedDaysDiff = moment
      .duration(
        moment(this.args.topic.bumped_at).diff(
          moment(this.args.topic.last_posted_at)
        )
      )
      .asDays();

    // If the bumped + last posted at are close together,
    // then we assume someone is editing shortly after posting,
    // in which case we should just show the last poster/first poster
    // as normal.
    //
    // In other cases, it's likely an edit or a topic bump that happened
    // a while after the last post, so we show no user.
    if (
      moment(this.args.topic.bumped_at).isAfter(
        this.args.topic.last_posted_at
      ) &&
      bumpedLastPostedDaysDiff > 1
    ) {
      return {
        username: undefined,
        class: "--updated",
      };
    }

    if (this.args.topic.posts_count > 1) {
      return {
        username: this.args.topic.last_poster_username,
        class: "--replied",
      };
    } else if (this.args.topic.posts_count === 1) {
      return {
        username: this.args.topic.last_poster_username,
        class: "--created",
      };
    } else {
      return;
    }
  }

  <template>
    <span class={{dConcatClass "topic-activity" this.topicUser.class}}>
      {{#if this.topicUser.username}}
        <span
          class="topic-activity__username"
        >{{this.topicUser.username}}</span>
        <span class="dot-separator"></span>
      {{/if}}
      <div class="topic-activity__time">
        {{dFormatDate @topic.bumpedAt leaveAgo="true" format="tiny"}}
      </div>
    </span>
  </template>
}
