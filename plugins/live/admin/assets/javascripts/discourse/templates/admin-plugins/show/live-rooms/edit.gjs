import LiveRoomForm from "discourse/plugins/live/discourse/components/live-room-form";

export default <template>
  <LiveRoomForm @onSave={{@controller.saveRoom}} @room={{@controller.model}} />
</template>
