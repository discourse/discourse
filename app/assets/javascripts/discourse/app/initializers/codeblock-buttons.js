import { cancel, later } from "@ember/runloop";
import showModal from "discourse/lib/show-modal";
import I18n from "I18n";
import { guidFor } from "@ember/object/internals";
import { clipboardCopy } from "discourse/lib/utilities";
import { iconHTML } from "discourse-common/lib/icon-library";
import { withPluginApi } from "discourse/lib/plugin-api";

let _codeblockButtonClickHandlers = {};
let _fadeCopyCodeblocksRunners = {};

export default {
  name: "codeblock-buttons",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");

    withPluginApi("0.8.7", (api) => {
      function _cleanUp() {
        Object.values(_codeblockButtonClickHandlers || {}).forEach((handler) =>
          handler.removeEventListener("click", _handleClick)
        );

        Object.values(_fadeCopyCodeblocksRunners || {}).forEach((runner) =>
          cancel(runner)
        );

        _codeblockButtonClickHandlers = {};
        _fadeCopyCodeblocksRunners = {};
      }

      function _copyComplete(button) {
        button.classList.add("action-complete");
        const state = button.innerHTML;
        button.innerHTML = I18n.t("copy_codeblock.copied");

        const commandId = guidFor(button);

        if (_fadeCopyCodeblocksRunners[commandId]) {
          cancel(_fadeCopyCodeblocksRunners[commandId]);
          delete _fadeCopyCodeblocksRunners[commandId];
        }

        _fadeCopyCodeblocksRunners[commandId] = later(() => {
          button.classList.remove("action-complete");
          button.innerHTML = state;
          delete _fadeCopyCodeblocksRunners[commandId];
        }, 3000);
      }

      function _handleClick(event) {
        if (
          !event.target.classList.contains("copy-cmd") &&
          !event.target.classList.contains("fullscreen-cmd")
        ) {
          return;
        }

        const action = event.target.classList.contains("fullscreen-cmd")
          ? "fullscreen"
          : "copy";
        const button = event.target;
        const codeEl = button.parentElement.querySelector("code");

        if (codeEl) {
          // replace any weird whitespace characters with a proper '\u20' whitespace
          const text = codeEl.innerText
            .replace(
              /[\f\v\u00a0\u1680\u2000-\u200a\u202f\u205f\u3000\ufeff]/g,
              " "
            )
            .trim();

          if (action === "copy") {
            const result = clipboardCopy(text);
            if (result.then) {
              result.then(() => {
                _copyComplete(button);
              });
            } else if (result) {
              _copyComplete(button);
            }
          } else if (action === "fullscreen") {
            showModal("fullscreen-code").setProperties({
              code: text,
              codeClasses: codeEl.className,
            });
          }
        }
      }

      function _attachCommands(postElement, helper) {
        if (!helper) {
          return;
        }

        if (!siteSettings.show_copy_button_on_codeblocks) {
          return;
        }

        let codeBlocks = [];
        try {
          codeBlocks = postElement.querySelectorAll(
            ":scope > pre > code, :scope :not(article):not(blockquote) > pre > code"
          );
        } catch (e) {
          // :scope is probably not supported by this browser
          codeBlocks = [];
        }

        const post = helper.getModel();

        if (!codeBlocks.length || !post) {
          return;
        }

        codeBlocks.forEach((codeBlock) => {
          const fullscreenButton = document.createElement("button");
          fullscreenButton.classList.add(
            "btn",
            "nohighlight",
            "fullscreen-cmd"
          );
          fullscreenButton.innerHTML = iconHTML("discourse-expand");
          codeBlock.before(fullscreenButton);

          const copyButton = document.createElement("button");
          copyButton.classList.add("btn", "nohighlight", "copy-cmd");
          copyButton.innerHTML = iconHTML("copy");
          codeBlock.before(copyButton);

          codeBlock.parentElement.classList.add("codeblock-buttons");
        });

        if (_codeblockButtonClickHandlers[post.id]) {
          _codeblockButtonClickHandlers[post.id].removeEventListener(
            "click",
            _handleClick
          );

          delete _codeblockButtonClickHandlers[post.id];
        }

        _codeblockButtonClickHandlers[post.id] = postElement;
        postElement.addEventListener("click", _handleClick, false);
      }

      api.decorateCookedElement(_attachCommands, {
        onlyStream: true,
        id: "codeblock-buttons",
      });

      api.cleanupStream(_cleanUp);
    });
  },
};
