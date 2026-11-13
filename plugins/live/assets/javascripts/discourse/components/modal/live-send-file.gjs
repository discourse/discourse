import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import { MEBIBYTE } from "../../lib/live/file-transfer-limits.js";

export default class LiveSendFileModal extends Component {
  @service liveWebrtc;

  @tracked error = null;
  @tracked sending = false;

  get maxSizeMiB() {
    return this.liveWebrtc.maxFileTransferSize / MEBIBYTE;
  }

  @action
  async chooseFile(event) {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file || this.sending) {
      return;
    }
    this.error = null;
    if (file.size > this.liveWebrtc.maxFileTransferSize) {
      this.error = i18n("live.file_transfer.too_large", {
        limit: this.maxSizeMiB,
      });
      return;
    }
    const { room, participant } = this.args.model;
    if (!this.liveWebrtc.canSendFile(room.id, participant.id)) {
      this.error = i18n("live.file_transfer.send_failed");
      return;
    }
    this.sending = true;
    try {
      await this.liveWebrtc.sendFile(room.id, participant.id, file);
      this.args.closeModal();
    } catch {
      this.error = i18n("live.file_transfer.send_failed");
    } finally {
      this.sending = false;
    }
  }

  <template>
    <DModal
      class="live-send-file-modal"
      @closeModal={{@closeModal}}
      @title="live.file_transfer.send"
    >
      <:body>
        <p>{{i18n
            "live.file_transfer.outgoing"
            username=@model.participant.username
          }}</p>
        <p>{{i18n "live.file_transfer.size_limit" limit=this.maxSizeMiB}}</p>
        <label>
          {{i18n "live.file_transfer.choose"}}
          <input
            disabled={{this.sending}}
            type="file"
            {{on "change" this.chooseFile}}
          />
        </label>
        {{#if this.error}}
          <p class="alert alert-error" role="alert">{{this.error}}</p>
        {{/if}}
      </:body>
    </DModal>
  </template>
}
