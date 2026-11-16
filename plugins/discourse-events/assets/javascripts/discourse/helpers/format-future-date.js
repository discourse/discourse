import { trustHTML } from "@ember/template";
import guessDateFormat from "../lib/guess-best-date-format.js";

export default function (date) {
  date = moment.utc(date).tz(moment.tz.guess());
  const format = guessDateFormat(date);
  return trustHTML(date.format(format));
}
