import { htmlSafe } from "@ember/template";
import { escapeExpression } from "discourse/lib/utilities";

export function jsonToHtml(json) {
  if (json === null) {
    return "null";
  }

  if (typeof json !== "object") {
    return escapeExpression(json);
  }

  let html = "<ul>";

  for (let [key, value] of Object.entries(json)) {
    html += "<li>";
    key = escapeExpression(key);

    if (typeof value === "object" && Array.isArray(value)) {
      html += `<strong>${key}:</strong> ${jsonToHtml(value)}`;
    } else if (typeof value === "object") {
      html += `<strong>${key}:</strong> <ul><li>${jsonToHtml(value)}</li></ul>`;
    } else {
      if (typeof value === "string") {
        value = escapeExpression(value).replace(/\n/g, "<br>");
      }
      html += `<strong>${key}:</strong> ${value}`;
    }

    html += "</li>";
  }

  html += "</ul>";
  return htmlSafe(html);
}
