import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import LiveRoomPage from "./room-page.gjs";

export default class LiveContextRoom extends Component {
  @service liveRooms;
  @service router;

  @action
  expandRoom(room) {
    this.router.transitionTo("live-room", room.slug);
  }

  <template>
    {{#each (array this.liveRooms.contextRoom) key="id" as |room|}}
      <div class="live-context-room">
        <DButton
          class="btn-transparent live-context-room__expand"
          @action={{fn this.expandRoom room}}
          @icon="discourse-expand"
          @label="live.room.open_page"
        />
        <LiveRoomPage @inContext={{true}} @room={{room}} />
      </div>
    {{/each}}
  </template>
}
