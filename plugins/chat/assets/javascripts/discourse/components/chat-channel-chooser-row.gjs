import { classNames } from "@ember-decorators/component";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";

@classNames("chat-channel-chooser-row")
export default class ChatChannelChooserRow extends SelectKitRowComponent {
  <template><ChannelTitle @channel={{this.item}} /></template>
}
