import { Plugin } from "@uppy/core";
import { warn } from "@ember/debug";
import { Promise } from "rsvp";

export default class UppyChecksum extends Plugin {
  constructor(uppy, opts) {
    super(uppy, opts);
    this.id = opts.id || "uppy-checksum";
    this.capabilities = opts.capabilities;
    this.type = "preprocessor";
  }

  _canUseSubtleCrypto() {
    if (!window.isSecureContext) {
      this.warnPrefixed(
        "Cannot generate cryptographic digests in an insecure context (not HTTPS)."
      );
      return false;
    }
    if (this.capabilities.isIE11) {
      this.warnPrefixed(
        "The required cipher suite is unavailable in Internet Explorer 11."
      );
      return false;
    }
    if (
      !(window.crypto && window.crypto.subtle && window.crypto.subtle.digest)
    ) {
      this.warnPrefixed(
        "The required cipher suite is unavailable in this browser."
      );
      return false;
    }

    return true;
  }

  _generateChecksum(fileIds) {
    if (!this._canUseSubtleCrypto()) {
      return Promise.resolve();
    }

    let promises = fileIds.map((fileId) => {
      let file = this.uppy.getFile(fileId);

      this.uppy.emit("preprocess-progress", file, {
        mode: "indeterminate",
        message: "generating checksum",
      });

      return file.data.arrayBuffer().then((arrayBuffer) => {
        return window.crypto.subtle
          .digest("SHA-1", arrayBuffer)
          .then((hash) => {
            const hashArray = Array.from(new Uint8Array(hash));
            const hashHex = hashArray
              .map((b) => b.toString(16).padStart(2, "0"))
              .join("");
            this.uppy.setFileMeta(fileId, { sha1_checksum: hashHex });
          })
          .catch((err) => {
            if (
              err.message.toString().includes("Algorithm: Unrecognized name")
            ) {
              this.warnPrefixed(
                "SHA-1 algorithm is unsupported in this browser."
              );
            }
          });
      });
    });

    const emitPreprocessCompleteForAll = () => {
      fileIds.forEach((fileId) => {
        const file = this.uppy.getFile(fileId);
        this.uppy.emit("preprocess-complete", file);
      });
    };

    return Promise.all(promises).then(emitPreprocessCompleteForAll);
  }

  warnPrefixed(message) {
    warn(`[uppy-checksum-plugin] ${message}`);
  }

  install() {
    this.uppy.addPreProcessor(this._generateChecksum.bind(this));
  }

  uninstall() {
    this.uppy.removePreProcessor(this._generateChecksum.bind(this));
  }
}
