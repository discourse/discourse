import LiveRoomList from "discourse/plugins/live/admin/components/live-room-list";

export default <template>
  <LiveRoomList
    @onDestroy={{@controller.destroyRoom}}
    @rooms={{@controller.model.content}}
  />
</template>
