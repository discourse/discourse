import { withPluginApi } from "discourse/lib/plugin-api";
import CodeblockButtons from "discourse/lib/codeblock-buttons";

let _codeblockButtons = [];

export default {
  name: "codeblock-buttons",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");

    withPluginApi("0.8.7", (api) => {
      function _cleanUp() {
        _codeblockButtons.forEach((cb) => cb.cleanup());
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

      api.decorateCookedElement(_attachCommands, {
        onlyStream: true,
        id: "codeblock-buttons",
      });

      api.cleanupStream(_cleanUp);
    });
  },
};
