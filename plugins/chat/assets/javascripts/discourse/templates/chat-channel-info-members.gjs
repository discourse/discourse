import RouteTemplate from "ember-route-template";
import ChannelInfoMembers from "discourse/plugins/chat/discourse/components/chat/routes/channel-info-members";

export default RouteTemplate(
  <template><ChannelInfoMembers @channel={{@controller.model}} /></template>
);
