import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("save-voice-credits-text-class", function (btnName) {
  if (btnName === "✓") {
    return "save-success";
  } else if (btnName === "X") {
    return "save-error";
  }
  return "";
});
