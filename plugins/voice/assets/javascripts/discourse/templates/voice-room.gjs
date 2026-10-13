import VoiceRoomPage from "discourse/plugins/voice/discourse/components/voice/room-page";

export default <template>
  <VoiceRoomPage
    @autoJoin={{@controller.join}}
    @dockOnJoin={{@controller.dockOnJoin}}
    @openChat={{@controller.chat}}
    @room={{@model}}
  />
</template>
