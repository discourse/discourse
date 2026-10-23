import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import AddMembers from "./add-members.gjs";
import { MODES } from "./constants.js";
import NewGroup from "./new-group.gjs";
import Search from "./search.gjs";

export default class ChatMessageCreator extends Component {
  @tracked mode = this.args.initialMode ?? MODES.search;
  @autoTrackedArray members = [];

  get componentForMode() {
    switch (this.args.mode ?? this.mode) {
      case MODES.search:
        return Search;
      case MODES.new_group:
        return NewGroup;
      case MODES.add_members:
        return AddMembers;
    }
  }

  @action
  changeMode(mode, members = []) {
    this.mode = mode;
    this.changeMembers(members);
  }

  @action
  changeMembers(members) {
    this.members = members;
  }

  @action
  cancelAction() {
    return this.args.onCancel?.() || this.changeMode(MODES.search);
  }

  <template>
    <div class="chat-message-creator-container">
      <div class="chat-message-creator">
        <this.componentForMode
          @cancel={{this.cancelAction}}
          @channel={{@channel}}
          @close={{@onClose}}
          @members={{this.members}}
          @onChangeMembers={{this.changeMembers}}
          @onChangeMode={{this.changeMode}}
        />
      </div>
    </div>
  </template>
}
