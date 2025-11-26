import { schedule } from "@ember/runloop";
import CodeblockButtons from "discourse/lib/codeblock-buttons";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  initialize(owner) {
    const site = owner.lookup("service:site");
    const siteSettings = owner.lookup("service:site-settings");

    withPluginApi((api) => {
      function _attachCommands(postElement, helper) {
        if (!helper) {
          return;
        }

        const post = helper.getModel();
        const cb = new CodeblockButtons({
          site,
          showFullscreen: true,
          showCopy: true,
        });

        // must be done after render so we can check the scroll width
        // of the code blocks
        schedule("afterRender", () => {
          cb.attachToPost(post, postElement);
        });

        return cb.cleanup;
      }

      if (siteSettings.show_copy_button_on_codeblocks) {
        api.decorateCookedElement(_attachCommands, {
          onlyStream: true,
        });
      }
    });
  },
};
