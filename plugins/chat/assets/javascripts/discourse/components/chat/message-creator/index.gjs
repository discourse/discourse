import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import AddMembers from "./add-members";
import { MODES } from "./constants";
import NewGroup from "./new-group";
import Search from "./search";

export default class ChatMessageCreator extends Component {
  @tracked mode = MODES.search;
  @tracked members = [];

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
          @channel={{@channel}}
          @onChangeMode={{this.changeMode}}
          @onChangeMembers={{this.changeMembers}}
          @close={{@onClose}}
          @cancel={{this.cancelAction}}
          @members={{this.members}}
        />
      </div>
    </div>
  </template>
}
