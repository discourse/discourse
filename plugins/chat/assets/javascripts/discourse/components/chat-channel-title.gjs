import Component from "@glimmer/component";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";

export default class OldChatChannelTitle extends Component {
  <template>
    <ChannelTitle @channel={{@channel}} />
  </template>
}
