import { getOwnerWithFallback } from "discourse/lib/get-owner";
import sanitizeError from "./sanitize-error.js";

// The diagnostic message must contain only trusted metadata. Error details
// belong in the optional error argument so they pass through sanitization.
export default {
  info(message) {
    if (
      getOwnerWithFallback()?.lookup("service:site-settings")
        ?.voice_verbose_logging
    ) {
      // eslint-disable-next-line no-console
      console.info(message);
    }
  },

  warn(message, error) {
    if (
      getOwnerWithFallback()?.lookup("service:site-settings")
        ?.voice_verbose_logging
    ) {
      const details = sanitizeError(error);
      // eslint-disable-next-line no-console
      console.warn(message, ...(details ? [details] : []));
    }
  },
};
