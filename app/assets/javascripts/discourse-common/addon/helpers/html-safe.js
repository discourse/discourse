import { htmlSafe as emberHtmlSafe } from "@ember/template";
import deprecated from "discourse-common/lib/deprecated";
import { registerRawHelper } from "discourse-common/lib/helpers";

registerRawHelper("html-safe", function (string) {
  return emberHtmlSafe(string);
});

export default function htmlSafe(string) {
  deprecated(
    "Importing htmlSafe from 'discourse-common/helpers/html-safe' is deprecated. Use { htmlSafe } from '@ember/template' instead.",
    {
      id: "discourse.html-safe",
      since: "3.3.0.beta2-dev",
    }
  );
  return emberHtmlSafe(string);
}
