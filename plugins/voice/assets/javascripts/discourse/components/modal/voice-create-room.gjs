import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import VoiceRoomForm from "discourse/plugins/voice/discourse/components/voice-room-form";

export default class VoiceCreateRoomModal extends Component {
  @service voiceRooms;
  @service toasts;

  @action
  async handleSubmit(data) {
    try {
      const result = await ajax("/voice/rooms", {
        type: "POST",
        data: { room: data },
      });
      this.voiceRooms.handleDirectoryEvent({
        type: "created",
        room: result.room,
      });
      this.toasts.success({ data: { message: i18n("voice.room.created") } });
      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <DModal
      class="voice-create-room-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "voice.sidebar.create"}}
    >
      <:body>
        <VoiceRoomForm @onSubmit={{this.handleSubmit}} />
      </:body>
    </DModal>
  </template>
}
