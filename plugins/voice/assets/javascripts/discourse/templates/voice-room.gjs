import bodyClass from "discourse/helpers/body-class";
import VoiceRoomPage from "discourse/plugins/voice/discourse/components/voice/room-page";

export default <template>
  {{bodyClass "has-full-page-chat"}}

  <VoiceRoomPage
    @autoJoin={{@controller.join}}
    @dockOnJoin={{@controller.dockOnJoin}}
    @openChat={{@controller.chat}}
    @room={{@model}}
  />
</template>
