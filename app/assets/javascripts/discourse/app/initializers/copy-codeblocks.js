import { withPluginApi } from "discourse/lib/plugin-api";
import { cancel, later } from "@ember/runloop";
import { Promise } from "rsvp";
import { iconHTML } from "discourse-common/lib/icon-library";
import I18n from "I18n";
import { guidFor } from "@ember/object/internals";

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

let _copyCodeblocksClickHandlers = {};
let _fadeCopyCodeblocksRunners = {};

export default {
  name: "copy-codeblocks",

  initialize(container) {
    withPluginApi("0.8.7", api => {
      function _cleanUp() {
        Object.values(_copyCodeblocksClickHandlers || {}).forEach(handler =>
          handler.removeEventListener("click", _handleClick)
        );

        Object.values(_fadeCopyCodeblocksRunners || {}).forEach(runner =>
          cancel(runner)
        );

        _copyCodeblocksClickHandlers = {};
        _fadeCopyCodeblocksRunners = {};
      }

      function _handleClick(event) {
        if (!event.target.classList.contains("copy-cmd")) {
          return;
        }

        const button = event.target;
        const code = button.nextSibling;

        if (code) {
          clipboardCopy(code.innerText.trim()).then(() => {
            button.classList.add("copied");
            const state = button.innerHTML;
            button.innerHTML = I18n.t("copy_codeblock.copied");

            const commandId = guidFor(button);

            if (_fadeCopyCodeblocksRunners[commandId]) {
              cancel(_fadeCopyCodeblocksRunners[commandId]);
              delete _fadeCopyCodeblocksRunners[commandId];
            }

            _fadeCopyCodeblocksRunners[commandId] = later(() => {
              button.classList.remove("copied");
              button.innerHTML = state;
              delete _fadeCopyCodeblocksRunners[commandId];
            }, 3000);
          });
        }
      }

      function _attachCommands(postElements, helper) {
        if (!helper) {
          return;
        }

        const siteSettings = container.lookup("site-settings:main");
        const { isIE11 } = container.lookup("capabilities:main");
        if (!siteSettings.show_copy_button_on_codeblocks || isIE11) {
          return;
        }

        let commands = [];
        try {
          commands = postElements[0].querySelectorAll(
            ":scope > pre > code, :scope :not(article):not(blockquote) > pre > code"
          );
        } catch (e) {
          // :scope is probably not supported by this browser
          commands = [];
        }

        const post = helper.getModel();

        if (!commands.length || !post) {
          return;
        }

        const postElement = postElements[0];

        commands.forEach(command => {
          const button = document.createElement("button");
          button.classList.add("btn", "nohighlight", "copy-cmd");
          button.innerHTML = iconHTML("copy");
          command.before(button);
          command.parentElement.classList.add("copy-codeblocks");
        });

        if (_copyCodeblocksClickHandlers[post.id]) {
          _copyCodeblocksClickHandlers[post.id].removeEventListener(
            "click",
            _handleClick
          );

          delete _copyCodeblocksClickHandlers[post.id];
        }

        _copyCodeblocksClickHandlers[post.id] = postElement;
        postElement.addEventListener("click", _handleClick, false);
      }

      api.decorateCooked(_attachCommands, {
        onlyStream: true,
        id: "copy-codeblocks"
      });

      api.cleanupStream(_cleanUp);
    });
  }
};
