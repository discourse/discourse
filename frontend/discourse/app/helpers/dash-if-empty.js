import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";

export default function dashIfEmpty(str) {
  return isEmpty(str) ? trustHTML("&mdash;") : str;
}
