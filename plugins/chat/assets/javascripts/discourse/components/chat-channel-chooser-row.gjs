import { tagName } from "@ember-decorators/component";
import SelectKitRowComponent from "discourse/select-kit/components/select-kit/select-kit-row";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";

@tagName("")
export default class ChatChannelChooserRow extends SelectKitRowComponent {
  <template>
    <div class="chat-channel-chooser-row" ...attributes>
      <ChannelTitle @channel={{this.item}} />
    </div>
  </template>
}
