import { trustHTML } from "@ember/template";
import { escapeExpression } from "discourse/lib/utilities";

/**
 * Deep-clones JSON-compatible data. FormKit deep-freezes its `@data` and every value
 * passed to `set`, so clone anything that must stay mutable elsewhere.
 *
 * @param {any} obj - The object to clone (can be null/undefined)
 * @returns {any} A deep, unfrozen copy
 */
export function toPlainObject(obj) {
  if (!obj) {
    return obj;
  }
  return JSON.parse(JSON.stringify(obj));
}

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
  return trustHTML(html);
}
