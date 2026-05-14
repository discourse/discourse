/* eslint-disable local/require-ts-check */
import { trustHTML } from "@ember/template";
import { durationTiny } from "discourse/lib/formatter";

export default function dFormatDuration(seconds) {
  return trustHTML(durationTiny(seconds));
}
