import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import raw from "discourse/helpers/raw";

export default class NewListHeaderControlsWrapper extends Component {
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
    <div
      {{! template-lint-disable no-invalid-interactive }}
      {{on "click" this.click}}
      class="topic-replies-toggle-wrapper"
    >
      {{raw
        "list/new-list-header-controls"
        current=@current
        newRepliesCount=@newRepliesCount
        newTopicsCount=@newTopicsCount
        noStaticLabel=true
      }}
    </div>
  </template>
}
