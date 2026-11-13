import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { deliverBlobDownload } from "discourse/lib/download-blob";
import DButton from "discourse/ui-kit/d-button";
import I18n, { i18n } from "discourse-i18n";
import { safeTransferFilename } from "../../lib/live/file-transfer-ui.js";

export default class LiveFileTransfer extends Component {
  @service liveWebrtc;
  @service liveRooms;

  @tracked saveError = false;
  @tracked saving = false;

  get filename() {
    return safeTransferFilename(this.args.transfer.name);
  }

  get size() {
    return I18n.toHumanSize(this.args.transfer.size);
  }

  get room() {
    return this.liveRooms.roomById(this.args.transfer.roomId);
  }

  get roomName() {
    return (
      this.room?.name ||
      i18n("live.file_transfer.room", { id: this.args.transfer.roomId })
    );
  }

  get peer() {
    const transfer = this.args.transfer;
    const participant = this.room?.active_participants?.find(
      (user) => user.id === transfer.userId
    );
    const username =
      participant?.username ||
      i18n("live.file_transfer.user", { id: transfer.userId });
    return i18n(`live.file_transfer.${transfer.direction}`, { username });
  }

  get status() {
    return i18n(`live.file_transfer.status.${this.args.transfer.status}`);
  }

  get transferError() {
    const code = this.args.transfer.error;
    if (["storage_unavailable", "storage_failed"].includes(code)) {
      return i18n(`live.file_transfer.${code}`);
    }
    return null;
  }

  get incomingPending() {
    return (
      this.args.transfer.direction === "incoming" &&
      this.args.transfer.status === "pending"
    );
  }

  get active() {
    return ["pending", "waiting", "initializing", "transferring"].includes(
      this.args.transfer.status
    );
  }

  get canSave() {
    return (
      this.args.transfer.direction === "incoming" &&
      this.args.transfer.status === "completed" &&
      this.args.transfer.hasFile === true
    );
  }

  get progress() {
    return Math.round(
      Math.max(0, Math.min(1, Number(this.args.transfer.progress) || 0)) * 100
    );
  }

  @action
  accept() {
    this.liveWebrtc.acceptFileTransfer(this.args.transfer.id);
  }

  @action
  reject() {
    this.liveWebrtc.rejectFileTransfer(this.args.transfer.id);
  }

  @action
  cancel() {
    this.liveWebrtc.cancelFileTransfer(this.args.transfer.id);
  }

  @action
  dismiss() {
    this.liveWebrtc.dismissFileTransfer(this.args.transfer.id);
  }

  @action
  async save() {
    this.saveError = false;
    this.saving = true;
    try {
      // Force an attachment download, never embed or navigate to remote content.
      // Discourse owns the temporary object URL and revokes it after download.
      const file = await this.liveWebrtc.getReceivedFile(this.args.transfer.id);
      // File.slice is a lazy disk-backed view; do not read bytes into RAM.
      await deliverBlobDownload(
        file.slice(0, file.size, "application/octet-stream"),
        { fallbackFilename: this.filename }
      );
    } catch {
      this.saveError = true;
    } finally {
      this.saving = false;
    }
  }

  <template>
    <li class="live-file-transfer" data-transfer-id={{@transfer.id}}>
      <div class="live-file-transfer__peer">{{this.peer}}
        ·
        {{this.roomName}}</div>
      <div class="live-file-transfer__name">{{this.filename}}
        ({{this.size}})</div>
      <div
        class="live-file-transfer__status"
        role="status"
      >{{this.status}}</div>
      {{#if this.active}}
        <progress
          aria-label={{this.filename}}
          max="100"
          value={{this.progress}}
        >{{this.progress}}%</progress>
      {{/if}}
      {{#if this.incomingPending}}
        <p class="live-file-transfer__safety">{{i18n
            "live.file_transfer.safety"
          }}</p>
      {{/if}}
      <div class="live-file-transfer__actions">
        {{#if this.incomingPending}}
          <DButton
            class="btn-primary live-file-transfer__accept"
            @action={{this.accept}}
            @label="live.file_transfer.accept"
          />
          <DButton
            class="live-file-transfer__reject"
            @action={{this.reject}}
            @label="live.file_transfer.reject"
          />
        {{else if this.active}}
          <DButton
            class="live-file-transfer__cancel"
            @action={{this.cancel}}
            @label="live.file_transfer.cancel"
          />
        {{/if}}
        {{#if this.canSave}}
          <DButton
            class="btn-primary live-file-transfer__save"
            @action={{this.save}}
            @disabled={{this.saving}}
            @label="live.file_transfer.save"
          />
        {{/if}}
        {{#unless this.active}}
          <DButton
            class="live-file-transfer__dismiss"
            @action={{this.dismiss}}
            @disabled={{this.saving}}
            @label="live.file_transfer.dismiss"
          />
        {{/unless}}
      </div>
      {{#if this.transferError}}
        <p
          class="live-file-transfer__error"
          role="alert"
        >{{this.transferError}}</p>
      {{/if}}
      {{#if this.saveError}}
        <p role="alert">{{i18n "live.file_transfer.save_failed"}}</p>
      {{/if}}
    </li>
  </template>
}
