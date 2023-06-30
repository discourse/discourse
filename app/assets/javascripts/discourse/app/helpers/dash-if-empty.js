import { isEmpty } from "@ember/utils";

export default function dashIfEmpty(str) {
  return isEmpty(str) ? "&mdash;" : str;
}
