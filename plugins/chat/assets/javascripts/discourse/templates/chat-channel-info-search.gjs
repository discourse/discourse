import RouteTemplate from "ember-route-template";
import ChannelInfoSearch from "discourse/plugins/chat/discourse/components/chat/routes/channel-info-search";

export default RouteTemplate(
  <template><ChannelInfoSearch @channel={{@controller.model}} /></template>
);
