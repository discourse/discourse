import bodyClass from "discourse/helpers/body-class";
import LiveRoomPage from "discourse/plugins/live/discourse/components/live/room-page";

export default <template>
  {{bodyClass "has-full-page-chat"}}

  <LiveRoomPage
    @autoJoin={{@controller.join}}
    @dockOnJoin={{@controller.dockOnJoin}}
    @openChat={{@controller.chat}}
    @room={{@model}}
  />
</template>
