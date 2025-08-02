import Component from "@glimmer/component";
import { service } from "@ember/service";
import ChatNotice from "./chat-notice";
import ChatRetentionReminder from "./chat-retention-reminder";

export default class ChatNotices extends Component {
  @service("chat-channel-notices-manager") noticesManager;

  get noticesForChannel() {
    return this.noticesManager.notices.filter(
      (notice) => notice.channelId === this.args.channel.id
    );
  }

  <template>
    <div class="chat-notices">
      <ChatRetentionReminder @channel={{@channel}} />

      {{#each this.noticesForChannel as |notice|}}
        <ChatNotice @notice={{notice}} @channel={{@channel}} />
      {{/each}}
    </div>
  </template>
}
