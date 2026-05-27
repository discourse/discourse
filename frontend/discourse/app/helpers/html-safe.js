import { trustHTML as emberHtmlSafe } from "@ember/template";
import deprecated from "discourse/lib/deprecated";

export default function htmlSafe(string) {
  deprecated(
    "`htmlSafe` from 'discourse/helpers/html-safe' is deprecated. Use `trustHTML` from '@ember/template' instead.",
    {
      id: "discourse.html-safe-helper",
      since: "2026.3.0",
    }
  );
  return emberHtmlSafe(string);
}
