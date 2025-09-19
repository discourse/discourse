import Component from "@glimmer/component";
import ChatSearch from "discourse/plugins/chat/discourse/components/chat-search";

export default class ChatRouteChannelInfoSearch extends Component {
  <template>
    <div class="c-routes --channel-info-search">
      <ChatSearch @query={{@query}} @scopedChannelId={{@channel.id}} />
    </div>
  </template>
}
