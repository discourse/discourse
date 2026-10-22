import { withPluginApi } from "discourse/lib/plugin-api";
import { TRANSCRIPT_DRAFT_KEY_PREFIX } from "../lib/live/transcript-draft-sync.js";

export default {
  name: "live-transcript-draft-icon",

  initialize() {
    withPluginApi((api) => {
      api.registerValueTransformer("draft-icon", ({ value, context }) => {
        return context.draft?.draft_key?.startsWith(TRANSCRIPT_DRAFT_KEY_PREFIX)
          ? "closed-captioning"
          : value;
      });
    });
  },
};
