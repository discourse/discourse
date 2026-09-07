import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { prioritizeNameInUx } from "discourse/lib/settings";
import DButton from "discourse/ui-kit/d-button";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import { speakQueue } from "../../lib/voice/speak-queue";

// The ordered request-to-speak queue of a stage room. Everyone sees the
// order; moderators get approve/dismiss controls, a queued viewer can lower
// their own hand.
export default class VoiceSpeakQueue extends Component {
  @service currentUser;
  @service voiceWebrtc;

  get room() {
    return this.args.room;
  }

  get canManage() {
    return this.room?.can_manage;
  }

  get entries() {
    return speakQueue(this.room).map((participant, index) => ({
      participant,
      position: index + 1,
      isSelf: Number(participant.id) === this.currentUser?.id,
      name: prioritizeNameInUx(participant.name)
        ? participant.name
        : participant.username,
    }));
  }

  @action
  async approve(participant) {
    try {
      await ajax(`/voice/rooms/${this.room.id}/memberships`, {
        type: "POST",
        data: { user_id: participant.id, role: "speaker" },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async dismiss(participant) {
    try {
      await ajax(`/voice/rooms/${this.room.id}/request_to_speak`, {
        type: "DELETE",
        data: { user_id: participant.id },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async lowerHand() {
    try {
      await ajax(`/voice/rooms/${this.room.id}/request_to_speak`, {
        type: "DELETE",
        data: {
          participant_session_id: this.voiceWebrtc.participantSessionIdFor(
            this.room.id
          ),
        },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <div class="voice-speak-queue">
      <h3 class="voice-speak-queue__title">
        {{i18n "voice.stage.queue_title"}}
      </h3>
      {{#if this.entries.length}}
        <ul class="voice-speak-queue__list">
          {{#each this.entries key="participant.id" as |entry|}}
            <li
              class={{dConcatClass
                "voice-speak-queue__item"
                (if entry.isSelf "--self")
              }}
            >
              <span
                class="voice-speak-queue__position"
              >{{entry.position}}</span>
              {{dAvatar entry.participant imageSize="small"}}
              <span class="voice-speak-queue__name">{{entry.name}}</span>
              <span class="voice-speak-queue__actions">
                {{#if this.canManage}}
                  <DButton
                    @action={{fn this.approve entry.participant}}
                    @icon="check"
                    @title="voice.stage.approve_request"
                    class="btn-transparent voice-speak-queue__approve"
                  />
                  <DButton
                    @action={{fn this.dismiss entry.participant}}
                    @icon="xmark"
                    @title="voice.stage.dismiss_request"
                    class="btn-transparent voice-speak-queue__dismiss"
                  />
                {{else if entry.isSelf}}
                  <DButton
                    @action={{this.lowerHand}}
                    @icon="xmark"
                    @title="voice.stage.lower_hand"
                    class="btn-transparent voice-speak-queue__lower"
                  />
                {{/if}}
              </span>
            </li>
          {{/each}}
        </ul>
      {{else}}
        <div class="voice-speak-queue__empty">
          {{i18n "voice.stage.queue_empty"}}
        </div>
      {{/if}}
    </div>
  </template>
}
