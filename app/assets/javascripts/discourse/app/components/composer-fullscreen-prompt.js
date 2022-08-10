import GlimmerComponent from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import I18n from "I18n";
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
          this.args.removeFullScreenExitPrompt();
        },
        { once: true }
      );
    });
  }

  get exitPrompt() {
    return I18n.t("composer.exit_fullscreen_prompt");
  }
}
