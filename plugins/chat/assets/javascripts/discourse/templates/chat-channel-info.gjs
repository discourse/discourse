import RouteTemplate from "ember-route-template";
import ChannelInfo from "discourse/plugins/chat/discourse/components/chat/routes/channel-info";

export default RouteTemplate(
  <template><ChannelInfo @channel={{@controller.model}} /></template>
);
