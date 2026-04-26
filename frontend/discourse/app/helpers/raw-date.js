import { trustHTML } from "@ember/template";
import { longDate } from "discourse/lib/formatter";

export default function rawDate(dt) {
  return trustHTML(longDate(new Date(dt)));
}
