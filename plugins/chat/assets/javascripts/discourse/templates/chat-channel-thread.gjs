import RouteTemplate from "ember-route-template";
import ChannelThread from "discourse/plugins/chat/discourse/components/chat/routes/channel-thread";

export default RouteTemplate(
  <template>
    <ChannelThread
      @thread={{@controller.model}}
      @targetMessageId={{@controller.targetMessageId}}
    />
  </template>
);
