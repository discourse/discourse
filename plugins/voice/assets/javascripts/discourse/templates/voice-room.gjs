import VoiceRoomPage from "discourse/plugins/voice/discourse/components/voice/room-page";

export default <template>
  <VoiceRoomPage
    @room={{@model}}
    @openChat={{@controller.chat}}
    @autoJoin={{@controller.join}}
    @dockOnJoin={{@controller.dockOnJoin}}
  />
</template>
