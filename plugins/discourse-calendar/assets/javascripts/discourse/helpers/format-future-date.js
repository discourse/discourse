import { htmlSafe } from "@ember/template";
import guessDateFormat from "../lib/guess-best-date-format";

export default function (date) {
  date = moment.utc(date).tz(moment.tz.guess());
  const format = guessDateFormat(date);
  return htmlSafe(date.format(format));
}
