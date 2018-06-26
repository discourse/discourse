import computed from "ember-addons/ember-computed-decorators";

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

export default Ember.Component.extend({
  classNames: ["backup-codes"],
  backupCodes: null,

  click(event) {
    if (event.target.id === "backupCodes") {
      this._selectAllBackupCodes();
    }
  },

  didRender() {
    this._super();

    const $backupCodes = this.$("#backupCodes");
    if ($backupCodes.length) {
      $backupCodes.height($backupCodes[0].scrollHeight);
    }
  },

  @computed("formattedBackupCodes") base64BackupCode: b64EncodeUnicode,

  @computed("backupCodes")
  formattedBackupCodes(backupCodes) {
    if (!backupCodes) return null;

    return backupCodes.join("\n").trim();
  },

  actions: {
    copyToClipboard() {
      this._selectAllBackupCodes();
      this.get("copyBackupCode")(document.execCommand("copy"));
    }
  },

  _selectAllBackupCodes() {
    const $textArea = this.$("#backupCodes");
    $textArea[0].focus();
    $textArea[0].setSelectionRange(0, this.get("formattedBackupCodes").length);
  }
});
