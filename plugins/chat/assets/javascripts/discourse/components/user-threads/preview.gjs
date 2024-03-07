import Component from "@glimmer/component";
import { service } from "@ember/service";
import formatDate from "discourse/helpers/format-date";

export default class ThreadPreview extends Component {
  <template>
    <span class="chat-message-thread-indicator__last-reply-timestamp">
      {{formatDate @preview.lastReplyCreatedAt leaveAgo="true"}}
    </span>
    <div class="c-user-thread__excerpt">
      <div class="c-user-thread__excerpt-poster">
        {{@preview.lastReplyUser.username}}<span>:</span>
      </div>
      {{@preview.lastReplyExcerpt}}
    </div>
  </template>
}
