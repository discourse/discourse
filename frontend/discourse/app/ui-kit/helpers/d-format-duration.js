import { trustHTML } from "@ember/template";
import { durationTiny } from "discourse/lib/formatter";

export default function dFormatDuration(seconds) {
  return trustHTML(durationTiny(seconds));
}
