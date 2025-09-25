import ChatSearch from "discourse/plugins/chat/discourse/components/chat-search";

const ChatRouteChannelInfoSearch = <template>
  <div class="c-routes --channel-info-search">
    <ChatSearch @query={{@query}} @scopedChannelId={{@channel.id}} />
  </div>
</template>;

export default ChatRouteChannelInfoSearch;
