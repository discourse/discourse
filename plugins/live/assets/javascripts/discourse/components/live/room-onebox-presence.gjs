import Component from "@glimmer/component";
import { service } from "@ember/service";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { i18n } from "discourse-i18n";

const MAX_AVATARS = 5;

// Who is in a room right now, rendered into its onebox card. The card itself
// is baked into the post, so this reads the live-rooms directory instead:
// it is scoped to the viewer and kept current over message bus, so the row
// updates as people join and leave.
export default class LiveRoomOneboxPresence extends Component {
  @service liveRooms;

  get room() {
    // Reading the tracked list subscribes this getter to directory updates;
    // the slug index itself is not tracked.
    return (
      this.liveRooms.rooms && this.liveRooms.roomBySlug(this.args.data.slug)
    );
  }

  get participants() {
    return this.room?.active_participants || [];
  }

  get shownParticipants() {
    return this.participants.slice(0, MAX_AVATARS);
  }

  get label() {
    return i18n("live.onebox.here_now", { count: this.participants.length });
  }

  <template>
    {{#if this.participants.length}}
      <div class="live-room-onebox__presence">
        <span aria-hidden="true" class="live-room-onebox__presence-dot"></span>
        <span class="live-room-onebox__presence-avatars">
          {{#each this.shownParticipants as |participant|}}
            <a
              aria-hidden="true"
              class="trigger-user-card"
              data-user-card={{participant.username}}
              tabindex="-1"
            >
              {{dAvatar participant imageSize="tiny"}}
            </a>
          {{/each}}
        </span>
        <span class="live-room-onebox__presence-label">{{this.label}}</span>
      </div>
    {{/if}}
  </template>
}
