import { Promise } from "rsvp";
import Component from "@ember/component";
import { action, computed } from "@ember/object";
import I18n from "I18n";

// http://github.com/feross/clipboard-copy
function clipboardCopy(text) {
  // Use the Async Clipboard API when available.
  // Requires a secure browsing context (i.e. HTTPS)
  if (navigator.clipboard) {
    return navigator.clipboard.writeText(text).catch(function(err) {
      throw err !== undefined
        ? err
        : new DOMException("The request is not allowed", "NotAllowedError");
    });
  }

  // ...Otherwise, use document.execCommand() fallback

  // Put the text to copy into a <span>
  const span = document.createElement("span");
  span.textContent = text;

  // Preserve consecutive spaces and newlines
  span.style.whiteSpace = "pre";

  // Add the <span> to the page
  document.body.appendChild(span);

  // Make a selection object representing the range of text selected by the user
  const selection = window.getSelection();
  const range = window.document.createRange();
  selection.removeAllRanges();
  range.selectNode(span);
  selection.addRange(range);

  // Copy text to the clipboard
  let success = false;
  try {
    success = window.document.execCommand("copy");
  } catch (err) {
    // eslint-disable-next-line no-console
    console.log("error", err);
  }

  // Cleanup
  selection.removeAllRanges();
  window.document.body.removeChild(span);

  return success
    ? Promise.resolve()
    : Promise.reject(
        new DOMException("The request is not allowed", "NotAllowedError")
      );
}

export default Component.extend({
  tagName: "",
  field: null,
  automation: null,

  placeholdersString: computed("field.placeholders", function() {
    return this.field.placeholders.join(", ");
  }),

  target: computed("field.target", function() {
    return this.field.target === "script"
      ? `.scriptables.${this.automation.script.id.replace(/-/g, "_")}.`
      : `.triggerables.${this.automation.trigger.id.replace(/-/g, "_")}.`;
  }),

  description: computed("field.target", function() {
    return I18n.lookup(
      `discourse_automation${this.target}fields.${this.field.name}.description`,
      { locale: I18n.locale }
    );
  }),

  @action
  copyPlaceholder(placeholder) {
    clipboardCopy(placeholder);
  }
});
