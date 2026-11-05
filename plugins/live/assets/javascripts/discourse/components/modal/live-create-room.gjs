import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import LiveRoomForm from "discourse/plugins/live/discourse/components/live-room-form";

export default class LiveCreateRoomModal extends Component {
  @service liveRooms;
  @service toasts;

  @action
  async handleSubmit(data) {
    try {
      const result = await ajax("/live/rooms", {
        type: "POST",
        data: { room: data },
      });
      this.liveRooms.handleDirectoryEvent({
        type: "created",
        room: result.room,
      });
      this.toasts.success({ data: { message: i18n("live.room.created") } });
      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <DModal
      class="live-create-room-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "live.sidebar.create"}}
    >
      <:body>
        <LiveRoomForm @onSubmit={{this.handleSubmit}} />
      </:body>
    </DModal>
  </template>
}
