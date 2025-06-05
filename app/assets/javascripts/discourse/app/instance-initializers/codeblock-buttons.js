import CodeblockButtons from "discourse/lib/codeblock-buttons";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  initialize(owner) {
    const siteSettings = owner.lookup("service:site-settings");

    withPluginApi("0.8.7", (api) => {
      api.decorateCookedElement(
        (postElement, helper) => {
          // if (!helper) {
          //   return;
          // }
          // if (!siteSettings.show_copy_button_on_codeblocks) {
          //   return;
          // }
          // const cb = new CodeblockButtons();
          // cb.attachToPost(postElement, helper);
        },
        { onlyStream: true }
      );
    });
  },
};
