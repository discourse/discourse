import { htmlSafe as emberHtmlSafe } from "@ember/template";
import deprecated from "discourse/lib/deprecated";

export default function htmlSafe(string) {
  deprecated(
    `Importing from 'discourse/helpers/html-safe' is deprecated. Use 'import { htmlSafe } from "@ember/template"' instead.`,
    {
      id: "discourse.html-safe-helper",
      since: "3.5.0.beta8-dev",
    }
  );
  return emberHtmlSafe(string);
}
