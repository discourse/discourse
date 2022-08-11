import { action } from "@ember/object";
import GlimmerComponent from "@glimmer/component";
import I18n from "I18n";

export default class ComposerFullscreenPrompt extends GlimmerComponent {
  @action
  registerAnimationListener(element) {
    this.#addAnimationEventListener(element);
  }

  #addAnimationEventListener(element) {
    element.addEventListener(
      "animationend",
      () => {
        this.args.removeFullScreenExitPrompt();
      },
      { once: true }
    );
  }

  get exitPrompt() {
    return I18n.t("composer.exit_fullscreen_prompt");
  }
}
