import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import icon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { unlockAudio } from "../../lib/voice/sound-effects";

export default class VoiceCallButton extends Component {
  @service("voice-calls") voiceCalls;

  // A plain button: the click must synchronously unlock the AudioContext so
  // the waiting tone can play once the call request round-trips, and deferred
  // action wrappers can outlive that activation.
  @action
  async call() {
    unlockAudio();
    try {
      await this.voiceCalls.callUser(this.args.user.username);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <button
      class="btn btn-icon-text btn-primary voice-call-button__button"
      type="button"
      {{on "click" this.call}}
    >
      {{icon "phone"}}
      <span class="d-button-label">{{i18n "voice.call.button"}}</span>
    </button>
  </template>
}
