import RouteTemplate from "ember-route-template";
import ChannelThreads from "discourse/plugins/chat/discourse/components/chat/routes/channel-threads";

export default RouteTemplate(
  <template><ChannelThreads @channel={{@controller.model}} /></template>
);
