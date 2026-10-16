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
import { speakQueue } from "../../lib/live/speak-queue.js";

// The ordered request-to-speak queue of a stage room. Everyone sees the
// order; moderators get approve/dismiss controls, a queued viewer can lower
// their own hand.
export default class LiveSpeakQueue extends Component {
  @service currentUser;
  @service liveWebrtc;

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
      await ajax(`/live/rooms/${this.room.id}/memberships`, {
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
      await ajax(`/live/rooms/${this.room.id}/request_to_speak`, {
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
      await ajax(`/live/rooms/${this.room.id}/request_to_speak`, {
        type: "DELETE",
        data: {
          participant_session_id: this.liveWebrtc.participantSessionIdFor(
            this.room.id
          ),
        },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <div class="live-speak-queue">
      <h3 class="live-speak-queue__title">
        {{i18n "live.stage.queue_title"}}
      </h3>
      {{#if this.entries.length}}
        <ul class="live-speak-queue__list">
          {{#each this.entries key="participant.id" as |entry|}}
            <li
              class={{dConcatClass
                "live-speak-queue__item"
                (if entry.isSelf "--self")
              }}
            >
              <span class="live-speak-queue__position">{{entry.position}}</span>
              {{dAvatar entry.participant imageSize="small"}}
              <span class="live-speak-queue__name">{{entry.name}}</span>
              <span class="live-speak-queue__actions">
                {{#if this.canManage}}
                  <DButton
                    class="btn-transparent live-speak-queue__approve"
                    @action={{fn this.approve entry.participant}}
                    @icon="check"
                    @title="live.stage.approve_request"
                  />
                  <DButton
                    class="btn-transparent live-speak-queue__dismiss"
                    @action={{fn this.dismiss entry.participant}}
                    @icon="xmark"
                    @title="live.stage.dismiss_request"
                  />
                {{else if entry.isSelf}}
                  <DButton
                    class="btn-transparent live-speak-queue__lower"
                    @action={{this.lowerHand}}
                    @icon="xmark"
                    @title="live.stage.lower_hand"
                  />
                {{/if}}
              </span>
            </li>
          {{/each}}
        </ul>
      {{else}}
        <div class="live-speak-queue__empty">
          {{i18n "live.stage.queue_empty"}}
        </div>
      {{/if}}
    </div>
  </template>
}
