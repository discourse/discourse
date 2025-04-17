import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import NewListHeaderControls from "discourse/components/topic-list/new-list-header-controls";

export default class NewListHeaderControlsWrapper extends Component {
  @service site;

  @action
  click(e) {
    const target = e.target;
    if (target.closest("button.topics-replies-toggle.--all")) {
      this.args.changeNewListSubset(null);
    } else if (target.closest("button.topics-replies-toggle.--topics")) {
      this.args.changeNewListSubset("topics");
    } else if (target.closest("button.topics-replies-toggle.--replies")) {
      this.args.changeNewListSubset("replies");
    }
  }

  <template>
    <div class="topic-replies-toggle-wrapper">
      <NewListHeaderControls
        @current={{@current}}
        @newRepliesCount={{@newRepliesCount}}
        @newTopicsCount={{@newTopicsCount}}
        @noStaticLabel={{true}}
        @changeNewListSubset={{@changeNewListSubset}}
      />
    </div>
  </template>
}
