import { on } from "@ember/modifier";
import htmlSafe from "discourse/helpers/html-safe";
import i18n from "discourse/helpers/i18n";
const ComposerFullscreenPrompt = <template><div class="composer-fullscreen-prompt" {{on "animationend" @removeFullScreenExitPrompt}}>
  {{htmlSafe (i18n "composer.exit_fullscreen_prompt")}}
</div></template>;
export default ComposerFullscreenPrompt;