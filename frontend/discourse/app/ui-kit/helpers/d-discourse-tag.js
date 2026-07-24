import { trustHTML } from "@ember/template";
import renderTag from "discourse/lib/render-tag";

export default function dDiscourseTag(name, params) {
  return trustHTML(renderTag(name, params));
}
