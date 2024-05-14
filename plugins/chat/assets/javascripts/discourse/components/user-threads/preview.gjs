import Component from "@glimmer/component";
import formatDate from "discourse/helpers/format-date";

export default class ThreadPreview extends Component {
  get lastReplyDate() {
    return formatDate(this.args.preview.lastReplyCreatedAt, { leaveAgo: true });
  }

  <template>
    <span class="chat-message-thread-indicator__last-reply-timestamp">
      {{this.lastReplyDate}}
    </span>
    <span class="c-user-thread__excerpt">
      <span class="c-user-thread__excerpt-poster">
        {{@preview.lastReplyUser.username}}
      </span>
      <span>:</span>
      <span class="c-user-thread__excerpt-text">
        {{@preview.lastReplyExcerpt}}
      </span>
    </span>
  </template>
}
