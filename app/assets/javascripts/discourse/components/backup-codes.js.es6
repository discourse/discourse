import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";

// https://developer.mozilla.org/en-US/docs/Web/API/WindowBase64/Base64_encoding_and_decoding
function b64EncodeUnicode(str) {
  return btoa(
    encodeURIComponent(str).replace(/%([0-9A-F]{2})/g, function toSolidBytes(
      match,
      p1
    ) {
      return String.fromCharCode("0x" + p1);
    })
  );
}

export default Component.extend({
  classNames: ["backup-codes"],
  backupCodes: null,

  click(event) {
    if (event.target.id === "backupCodes") {
      this._selectAllBackupCodes();
    }
  },

  didRender() {
    this._super(...arguments);

    const backupCodes = this.element.querySelector("#backupCodes");
    if (backupCodes) {
      backupCodes.style.height = backupCodes.scrollHeight;
    }
  },

  @discourseComputed("formattedBackupCodes")
  base64BackupCode: b64EncodeUnicode,

  @discourseComputed("backupCodes")
  formattedBackupCodes(backupCodes) {
    if (!backupCodes) return null;

    return backupCodes.join("\n").trim();
  },

  actions: {
    copyToClipboard() {
      this._selectAllBackupCodes();
      this.copyBackupCode(document.execCommand("copy"));
    }
  },

  _selectAllBackupCodes() {
    const textArea = this.element.querySelector("#backupCodes");
    textArea.focus();
    textArea.setSelectionRange(0, this.formattedBackupCodes.length);
  }
});
