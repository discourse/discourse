import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import routeAction from "discourse/helpers/route-action";
import PollOptionRankedChoiceDropdown from "./poll-option-ranked-choice-dropdown";

export default class PollOptionsComponent extends Component {
  @service currentUser;

  @action
  sendRank(option, rank = 0) {
    this.args.sendRank(option, rank);
  }

  <template>
    <div
      tabindex="0"
      class="ranked-choice-poll-option"
      data-poll-option-id={{@option.id}}
      data-poll-option-rank={{@option.rank}}
    >
      {{#if this.currentUser}}
        <PollOptionRankedChoiceDropdown
          @rank={{@option.rank}}
          @option={{@option}}
          @rankedChoiceDropdownContent={{@rankedChoiceDropdownContent}}
          @sendRank={{this.sendRank}}
        />
      {{else}}
        <DButton
          @action={{routeAction "showLogin"}}
          @label="poll.options.ranked_choice.login"
          class="btn-default"
        />
      {{/if}}
      <span class="option-text">{{htmlSafe @option.html}}</span>
    </div>
  </template>
}
