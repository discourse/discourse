import GlimmerComponent from "@glimmer/component";
import I18n from "I18n";
import { htmlSafe } from "@ember/template";
import { next } from "@ember/runloop";

export default class ComposerFullscreenPrompt extends GlimmerComponent {
  constructor() {
    super(...arguments);
    this.#setupFullscreenPrompt();
  }

  #setupFullscreenPrompt() {
    next(() => {
      const promptElement = document.querySelector(
        ".composer-fullscreen-prompt"
      );

      promptElement?.addEventListener(
        "animationend",
        () => {
          this.args.model.set("showFullScreenExitPrompt", false);
        },
        { once: true }
      );
    });
  }

  get exitPrompt() {
    return htmlSafe(I18n.t("composer.exit_fullscreen_prompt"));
  }
}
