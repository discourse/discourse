import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";

export default class ThreadPreview extends Component {
  get lastReplyDate() {
    return dFormatDate(this.args.preview.lastReplyCreatedAt, {
      leaveAgo: true,
    });
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
        {{dReplaceEmoji (trustHTML @preview.lastReplyExcerpt)}}
      </span>
    </span>
  </template>
}
