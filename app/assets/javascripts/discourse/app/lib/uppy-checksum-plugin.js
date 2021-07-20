import { Plugin } from "@uppy/core";
import { Promise } from "rsvp";

export default class UppyChecksum extends Plugin {
  constructor(uppy, opts) {
    super(uppy, opts);
    opts = opts || {};
    this.id = opts.id || "uppy-checksum";
    this.capabilities = opts.capabilities;

    // this is meaningless, can be anything
    this.type = "preprocessor";
  }

  canUseSubtleCrypto() {
    if (!window.isSecureContext) {
      this.warn(
        "Cannot generate cryptographic digests in an insecure context (not HTTPS)."
      );
      return false;
    }
    if (this.capabilities.isIE11) {
      this.warn(
        "The required cipher suite is unavailable in Internet Explorer 11."
      );
      return false;
    }
    if (
      !(window.crypto && window.crypto.subtle && window.crypto.subtle.digest)
    ) {
      this.warn("The required cipher suite is unavailable in this browser.");
      return false;
    }

    return true;
  }

  generateChecksum(fileIds) {
    if (!this.canUseSubtleCrypto()) {
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
              this.warn("SHA-1 algorithm is unsupported in this browser.");
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

  warn(message) {
    // eslint-disable-next-line no-console
    console.warn("[uppy-checksum-plugin] " + message);
  }

  install() {
    this.uppy.addPreProcessor(this.generateChecksum.bind(this));
  }

  uninstall() {
    this.uppy.removePreProcessor(this.generateChecksum.bind(this));
  }
}
