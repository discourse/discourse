import { withPluginApi } from "discourse/lib/plugin-api";
import { TRANSCRIPT_SOURCE_TYPE } from "../lib/voice/transcript-markdown.js";

export default {
  name: "voice-transcript-source",

  initialize() {
    withPluginApi((api) => {
      // absent when the chat plugin isn't installed
      api.registerChatTranscriptSourceType?.(TRANSCRIPT_SOURCE_TYPE, {
        icon: "microphone-lines",
        label: "voice.transcript.source_label",
      });
    });
  },
};
