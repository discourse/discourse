import { cancel, later } from "@ember/runloop";
import I18n from "I18n";
import { guidFor } from "@ember/object/internals";
import { clipboardCopy } from "discourse/lib/utilities";
import { iconHTML } from "discourse-common/lib/icon-library";
import { withPluginApi } from "discourse/lib/plugin-api";

let _copyCodeblocksClickHandlers = {};
let _fadeCopyCodeblocksRunners = {};

export default {
  name: "copy-codeblocks",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");

    withPluginApi("0.8.7", (api) => {
      function _cleanUp() {
        Object.values(_copyCodeblocksClickHandlers || {}).forEach((handler) =>
          handler.removeEventListener("click", _handleClick)
        );

        Object.values(_fadeCopyCodeblocksRunners || {}).forEach((runner) =>
          cancel(runner)
        );

        _copyCodeblocksClickHandlers = {};
        _fadeCopyCodeblocksRunners = {};
      }

      function _copyComplete(button) {
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
      }

      function _handleClick(event) {
        if (!event.target.classList.contains("copy-cmd")) {
          return;
        }

        const button = event.target;
        const code = button.nextSibling;

        if (code) {
          // replace any weird whitespace characters with a proper '\u20' whitespace
          const text = code.innerText
            .replace(
              /[\f\v\u00a0\u1680\u2000-\u200a\u202f\u205f\u3000\ufeff]/g,
              " "
            )
            .trim();

          const result = clipboardCopy(text);
          if (result.then) {
            result.then(() => {
              _copyComplete(button);
            });
          } else if (result) {
            _copyComplete(button);
          }
        }
      }

      function _attachCommands(postElements, helper) {
        if (!helper) {
          return;
        }

        if (!siteSettings.show_copy_button_on_codeblocks) {
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

        commands.forEach((command) => {
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
        id: "copy-codeblocks",
      });

      api.cleanupStream(_cleanUp);
    });
  },
};
