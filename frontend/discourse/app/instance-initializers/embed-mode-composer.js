import { USER_OPTION_COMPOSITION_MODES } from "discourse/lib/constants";
import EmbedMode from "discourse/lib/embed-mode";
import { withPluginApi } from "discourse/lib/plugin-api";

const EMBED_COMPOSER_HEIGHT = "50dvh";

function setEmbedComposerHeight() {
  document.documentElement.style.setProperty(
    "--composer-height",
    EMBED_COMPOSER_HEIGHT
  );
}

export default {
  after: "inject-objects",

  initialize(owner) {
    if (!EmbedMode.enabled) {
      return;
    }

    this._owner = owner;
    this._handler = setEmbedComposerHeight;

    owner.lookup("service:app-events").on("composer:open", this._handler);

    withPluginApi((api) => {
      api.registerValueTransformer("composer-force-editor-mode", () => {
        return USER_OPTION_COMPOSITION_MODES.rich;
      });
    });
  },

  teardown() {
    if (this._handler) {
      this._owner
        .lookup("service:app-events")
        .off("composer:open", this._handler);
      this._handler = null;
      this._owner = null;
    }
  },
};
