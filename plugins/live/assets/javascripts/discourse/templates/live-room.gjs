import LiveRoomPage from "discourse/plugins/live/discourse/components/live/room-page";

export default <template>
  <LiveRoomPage
    @autoJoin={{@controller.join}}
    @dockOnJoin={{@controller.dockOnJoin}}
    @openChat={{@controller.chat}}
    @room={{@model}}
  />
</template>
