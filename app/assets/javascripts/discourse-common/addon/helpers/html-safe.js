import { htmlSafe } from "@ember/template";
import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("html-safe", function (string) {
  return htmlSafe(string);
});
