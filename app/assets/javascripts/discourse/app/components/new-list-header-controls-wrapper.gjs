import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import NewListHeaderControls from "discourse/components/topic-list/new-list-header-controls";
import raw from "discourse/helpers/raw";

export default class NewListHeaderControlsWrapper extends Component {
  @service currentUser;

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
    {{#if this.currentUser.canUseGlimmerTopicList}}
      <div class="topic-replies-toggle-wrapper">
        <NewListHeaderControls
          @current={{@current}}
          @newRepliesCount={{@newRepliesCount}}
          @newTopicsCount={{@newTopicsCount}}
          @noStaticLabel={{true}}
          @changeNewListSubset={{@changeNewListSubset}}
        />
      </div>
    {{else}}
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
    {{/if}}
  </template>
}
