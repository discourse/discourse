import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("save-voice-credits-button-class", function (btnName) {
  if (btnName === "✓") {
    return "btn btn-success";
  } else if (btnName === "X") {
    return "btn btn-error";
  }
  return "btn";
});
