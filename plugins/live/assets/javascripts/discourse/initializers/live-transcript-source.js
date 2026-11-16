import { withPluginApi } from "discourse/lib/plugin-api";
import { TRANSCRIPT_SOURCE_TYPE } from "../lib/live/transcript-markdown.js";

export default {
  name: "live-transcript-source",

  initialize() {
    withPluginApi((api) => {
      // absent when the chat plugin isn't installed
      api.registerChatTranscriptSourceType?.(TRANSCRIPT_SOURCE_TYPE, {
        icon: "microphone-lines",
        label: "live.transcript.source_label",
      });
    });
  },
};
