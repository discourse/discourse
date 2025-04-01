import RouteTemplate from "ember-route-template";
import ChannelInfoSettings from "discourse/plugins/chat/discourse/components/chat/routes/channel-info-settings";

export default RouteTemplate(
  <template><ChannelInfoSettings @channel={{@controller.model}} /></template>
);
