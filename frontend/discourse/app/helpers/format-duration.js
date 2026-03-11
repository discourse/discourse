import { trustHTML } from "@ember/template";
import { durationTiny } from "discourse/lib/formatter";

export default function formatDuration(seconds) {
  return trustHTML(durationTiny(seconds));
}
