import { registerUnbound } from "discourse-common/lib/helpers";
import { htmlSafe } from "@ember/template";

registerUnbound("html-safe", function(string) {
  return htmlSafe(string);
});
