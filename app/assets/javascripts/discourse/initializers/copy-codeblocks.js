import { withPluginApi } from "discourse/lib/plugin-api";
import { cancel, later } from "@ember/runloop";
import { Promise } from "rsvp";
import { iconHTML } from "discourse-common/lib/icon-library";

// http://github.com/feross/clipboard-copy
function clipboardCopy(text) {
  // Use the Async Clipboard API when available. Requires a secure browsing
  // context (i.e. HTTPS)
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

let _clickHandlerElement = null;
let _runLater = null;

export default {
  name: "copy-codeblocks",

  initialize(container) {
    withPluginApi("0.8.7", api => {
      function _cleanUp() {
        if (_clickHandlerElement) {
          _clickHandlerElement.removeEventListener("click", _handleClick);
          _clickHandlerElement = null;
        }
        if (_runLater) {
          cancel(_runLater);
          _runLater = null;
        }
      }

      function _handleClick(event) {
        if (!event.target.classList.contains("copy-cmd")) {
          return;
        }

        const button = event.target;
        const code = button.nextSibling;

        if (code) {
          let string = code.innerText;

          if (string) {
            string = string.trim();
            clipboardCopy(string);
          }

          button.classList.add("copied");

          _runLater = later(() => button.classList.remove("copied"), 3000);
        }
      }

      function _attachCommands($elem) {
        const siteSettings = container.lookup("site-settings:main");
        const { isIE11 } = container.lookup("capabilities:main");
        if (!siteSettings.show_copy_button_on_codeblocks || isIE11) {
          return;
        }
        const commands = $elem[0].querySelectorAll(":scope > pre > code");

        if (!commands.length) {
          return;
        }

        _clickHandlerElement = $elem[0];

        commands.forEach(command => {
          const button = document.createElement("button");
          button.classList.add("btn", "nohighlight", "copy-cmd");
          button.innerHTML = iconHTML("copy");
          command.before(button);
          command.parentElement.classList.add("copy-codeblocks");
        });

        _clickHandlerElement.addEventListener("click", _handleClick, false);
      }

      api.decorateCooked(_attachCommands, { id: "copy-codeblocks" });

      api.cleanupStream(_cleanUp);
    });
  }
};
