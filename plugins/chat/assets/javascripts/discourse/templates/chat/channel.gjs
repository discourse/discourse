import RouteTemplate from "ember-route-template";
import Channel from "discourse/plugins/chat/discourse/components/chat/routes/channel";

export default RouteTemplate(
  <template>
    <Channel
      @channel={{@controller.model}}
      @targetMessageId={{@controller.targetMessageId}}
    />
  </template>
);
