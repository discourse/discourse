import { getOwnerWithFallback } from "discourse/lib/get-owner";

// Only pass diagnostic messages and trusted scalar metadata; never errors,
// response bodies, participant objects, transcripts, SDP, or ICE candidates.
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

  warn(message) {
    if (
      getOwnerWithFallback()?.lookup("service:site-settings")
        ?.voice_verbose_logging
    ) {
      // eslint-disable-next-line no-console
      console.warn(message);
    }
  },
};
