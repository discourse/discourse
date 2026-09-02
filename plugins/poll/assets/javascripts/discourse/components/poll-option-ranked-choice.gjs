import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import routeAction from "discourse/helpers/route-action";
import DButton from "discourse/ui-kit/d-button";
import decoratePollOption from "../modifiers/decorate-poll-option";
import PollOptionRankedChoiceDropdown from "./poll-option-ranked-choice-dropdown";

export default class PollOptionsComponent extends Component {
  @service currentUser;

  @action
  sendRank(option, rank = 0) {
    this.args.sendRank(option, rank);
  }

  <template>
    <div
      class="ranked-choice-poll-option"
      data-poll-option-id={{@option.id}}
      data-poll-option-rank={{@option.rank}}
      tabindex="0"
    >
      {{#if this.currentUser}}
        <PollOptionRankedChoiceDropdown
          @option={{@option}}
          @rank={{@option.rank}}
          @rankedChoiceDropdownContent={{@rankedChoiceDropdownContent}}
          @sendRank={{this.sendRank}}
        />
      {{else}}
        <DButton
          class="btn-default"
          @action={{routeAction "showLogin"}}
          @label="poll.options.ranked_choice.login"
        />
      {{/if}}
      <span class="option-text" {{decoratePollOption @option.html}}></span>
    </div>
  </template>
}
