import { schedule } from "@ember/runloop";
import CodeblockButtons from "discourse/lib/codeblock-buttons";
import { withPluginApi } from "discourse/lib/plugin-api";

let _codeblockButtons = [];

export default {
  initialize(owner) {
    const siteSettings = owner.lookup("service:site-settings");

    withPluginApi("0.8.7", (api) => {
      function _cleanUp() {
        _codeblockButtons.forEach((cb) => cb.cleanup());
        _codeblockButtons.length = 0;
      }

      function _attachCommands(postElement, helper) {
        if (!helper) {
          return;
        }

        if (!siteSettings.show_copy_button_on_codeblocks) {
          return;
        }

        const post = helper.getModel();
        const cb = new CodeblockButtons({
          showFullscreen: true,
          showCopy: true,
        });
        cb.attachToPost(post, postElement);

        _codeblockButtons.push(cb);
      }

      api.decorateCookedElement(
        (postElement, helper) => {
          // must be done after render so we can check the scroll width
          // of the code blocks
          schedule("afterRender", () => {
            _attachCommands(postElement, helper);
          });
        },
        {
          onlyStream: true,
        }
      );

      api.cleanupStream(_cleanUp);
    });
  },
};
