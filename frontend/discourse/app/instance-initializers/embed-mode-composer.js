import { USER_OPTION_COMPOSITION_MODES } from "discourse/lib/constants";
import EmbedMode from "discourse/lib/embed-mode";
import { withPluginApi } from "discourse/lib/plugin-api";
import Composer from "discourse/models/composer";

export default {
  after: "inject-objects",

  initialize(owner) {
    if (!EmbedMode.enabled) {
      return;
    }

    const appEvents = owner.lookup("service:app-events");

    appEvents.on("composer:open", () => {
      const composerService = owner.lookup("service:composer");
      if (composerService.model?.composeState !== Composer.FULLSCREEN) {
        composerService.model.set("composeState", Composer.FULLSCREEN);
      }
    });

    withPluginApi((api) => {
      api.registerValueTransformer("composer-force-editor-mode", () => {
        return USER_OPTION_COMPOSITION_MODES.rich;
      });
    });
  },
};
