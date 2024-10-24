import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import copyText from "discourse/lib/copy-text";
import { slugify, toAsciiPrintable } from "discourse/lib/utilities";
import i18n from "discourse-common/helpers/i18n";

// https://developer.mozilla.org/en-US/docs/Web/API/WindowBase64/Base64_encoding_and_decoding
function b64EncodeUnicode(str) {
  return btoa(
    encodeURIComponent(str).replace(
      /%([0-9A-F]{2})/g,
      function toSolidBytes(match, p1) {
        return String.fromCharCode("0x" + p1);
      }
    )
  );
}

export default class BackupCodes extends Component {
  @service siteSettings;

  get siteTitleSlug() {
    const title = this.siteSettings.title;
    const convertedTitle = toAsciiPrintable(title, "discourse");
    return slugify(convertedTitle);
  }

  get base64BackupCode() {
    return b64EncodeUnicode(this.formattedBackupCodes);
  }

  get formattedBackupCodes() {
    if (!this.args.backupCodes) {
      return null;
    }

    return this.args.backupCodes.join("\r\n").trim();
  }

  @action
  copyToClipboard() {
    this._selectAllBackupCodes();
    const copied = copyText("", this.backupCodesArea);
    this.args.copyBackupCode(copied);
  }

  @action
  registerBackupCodesArea(element) {
    this.backupCodesArea = element;
    element.style.height = element.scrollHeight;
  }

  @action
  _selectAllBackupCodes() {
    this.backupCodesArea.focus();
    this.backupCodesArea.setSelectionRange(0, this.formattedBackupCodes.length);
  }

  <template>
    <div class="backup-codes">
      <div class="wrapper">
        <textarea
          id="backupCodes"
          class="backup-codes-area"
          rows="10"
          readonly
          {{didInsert this.registerBackupCodesArea}}
          {{on "click" this._selectAllBackupCodes}}
        >{{this.formattedBackupCodes}}</textarea>

        <div class="controls">
          <DButton
            @action={{this.copyToClipboard}}
            @icon="copy"
            @ariaLabel="user.second_factor_backup.copy_to_clipboard"
            @title="user.second_factor_backup.copy_to_clipboard"
            class="backup-codes-copy-btn"
          />

          <DButton
            download="{{this.siteTitleSlug}}-backup-codes.txt"
            class="backup-codes-download-btn"
            aria-label={{i18n
              "user.second_factor_backup.download_backup_codes"
            }}
            title={{i18n "user.second_factor_backup.download_backup_codes"}}
            rel="noopener noreferrer"
            target="_blank"
            @href="data:application/octet-stream;charset=utf-8;base64,{{this.base64BackupCode}}"
            @icon="download"
          />
        </div>
      </div>
    </div>
  </template>
}
