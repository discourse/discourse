import { BasePlugin } from "@uppy/core";
import { warn } from "@ember/debug";
import { Promise } from "rsvp";

export default class UppyChecksum extends BasePlugin {
  constructor(uppy, opts) {
    super(uppy, opts);
    this.id = opts.id || "uppy-checksum";
    this.pluginClass = this.constructor.name;
    this.capabilities = opts.capabilities;
    this.type = "preprocessor";
  }

  _canUseSubtleCrypto() {
    if (!this._secureContext()) {
      warn(
        "Cannot generate cryptographic digests in an insecure context (not HTTPS).",
        {
          id: "discourse.uppy-media-optimization",
        }
      );
      return false;
    }
    if (this.capabilities.isIE11) {
      warn(
        "The required cipher suite is unavailable in Internet Explorer 11.",
        {
          id: "discourse.uppy-media-optimization",
        }
      );
      return false;
    }
    if (!this._hasCryptoCipher()) {
      warn("The required cipher suite is unavailable in this browser.", {
        id: "discourse.uppy-media-optimization",
      });
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

      this.uppy.emit("preprocess-progress", this.pluginClass, file);

      return file.data.arrayBuffer().then((arrayBuffer) => {
        return window.crypto.subtle
          .digest("SHA-1", arrayBuffer)
          .then((hash) => {
            const hashArray = Array.from(new Uint8Array(hash));
            const hashHex = hashArray
              .map((b) => b.toString(16).padStart(2, "0"))
              .join("");
            this.uppy.setFileMeta(fileId, { sha1_checksum: hashHex });
            this.uppy.emit("preprocess-complete", this.pluginClass, file);
          })
          .catch((err) => {
            if (
              err.message.toString().includes("Algorithm: Unrecognized name")
            ) {
              warn("SHA-1 algorithm is unsupported in this browser.", {
                id: "discourse.uppy-media-optimization",
              });
            } else {
              warn(`Error encountered when generating digest: ${err.message}`, {
                id: "discourse.uppy-media-optimization",
              });
            }
            this.uppy.emit("preprocess-complete", this.pluginClass, file);
          });
      });
    });

    return Promise.all(promises);
  }

  _secureContext() {
    return window.isSecureContext;
  }

  _hasCryptoCipher() {
    return window.crypto && window.crypto.subtle && window.crypto.subtle.digest;
  }

  install() {
    this.uppy.addPreProcessor(this._generateChecksum.bind(this));
  }

  uninstall() {
    this.uppy.removePreProcessor(this._generateChecksum.bind(this));
  }
}
