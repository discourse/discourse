import RouteTemplate from "ember-route-template";
import ChatRouteChannelInfoSearch from "discourse/plugins/chat/discourse/components/chat/routes/channel-info-search";

export default RouteTemplate(
  <template>
    <ChatRouteChannelInfoSearch
      @query={{@controller.q}}
      @channel={{@controller.model}}
    />
  </template>
);
