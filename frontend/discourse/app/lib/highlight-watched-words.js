import { trustHTML } from "@ember/template";
import highlightHTML from "discourse/lib/highlight-html";

export default function (text, reviewable) {
  if (!text) {
    return text;
  }

  if (!reviewable || !reviewable.reviewable_scores) {
    return trustHTML(text);
  }

  const words = reviewable.reviewable_scores
    .map((rs) => {
      return rs.reason_type === "watched_word" ? rs.reason_data : [];
    })
    .flat();

  if (!words.length) {
    return trustHTML(text);
  }

  const elem = document.createElement("span");
  elem.innerHTML = text;

  words.forEach((word) => {
    highlightHTML(elem, word, {
      nodeName: "mark",
      className: "watched-word-highlight",
    });
  });

  return trustHTML(elem.innerHTML);
}
