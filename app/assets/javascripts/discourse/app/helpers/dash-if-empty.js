import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";

export default function dashIfEmpty(str) {
  return isEmpty(str) ? htmlSafe("&mdash;") : str;
}
