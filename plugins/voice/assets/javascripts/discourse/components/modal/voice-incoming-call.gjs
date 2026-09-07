import Component from "@glimmer/component";
import { action } from "@ember/object";
import { prioritizeNameInUx } from "discourse/lib/settings";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { i18n } from "discourse-i18n";

export default class VoiceIncomingCallModal extends Component {
  #expiryTimer;

  constructor() {
    super(...arguments);
    // An unanswered call stops ringing on its own — the modal closing is what
    // stops the ringtone, so the expiry lives here.
    this.#expiryTimer = setTimeout(
      () => this.args.closeModal(),
      this.args.model.remainingMs
    );
  }

  willDestroy() {
    super.willDestroy(...arguments);
    clearTimeout(this.#expiryTimer);
  }

  get ring() {
    return this.args.model.ring;
  }

  get caller() {
    return {
      username: this.ring.caller_username,
      name: this.ring.caller_name,
      avatar_template: this.ring.caller_avatar_template,
    };
  }

  get displayName() {
    return prioritizeNameInUx(this.caller.name)
      ? this.caller.name
      : this.caller.username;
  }

  @action
  answer() {
    this.args.closeModal();
    this.args.model.calls.answer(this.ring);
  }

  @action
  decline() {
    this.args.closeModal();
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "voice.call.incoming_title"}}
      class="voice-incoming-call-modal"
    >
      <:body>
        <div class="voice-incoming-call-modal__caller">
          <div class="voice-incoming-call-modal__avatar">
            {{dAvatar this.caller imageSize="huge"}}
          </div>
          <span
            class="voice-incoming-call-modal__name"
          >{{this.displayName}}</span>
          <span class="voice-incoming-call-modal__state">
            {{i18n "voice.call.incoming_state"}}
          </span>
        </div>
      </:body>
      <:footer>
        <DButton
          @action={{this.answer}}
          @icon="phone"
          @label="voice.call.answer"
          class="btn-primary voice-incoming-call-modal__answer"
        />
        <DButton
          @action={{this.decline}}
          @icon="phone-slash"
          @label="voice.call.decline"
          class="btn-danger voice-incoming-call-modal__decline"
        />
      </:footer>
    </DModal>
  </template>
}
