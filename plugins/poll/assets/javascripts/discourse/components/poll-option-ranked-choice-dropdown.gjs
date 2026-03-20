import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class PollOptionsDropdownComponent extends Component {
  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  selectRank(option, rank) {
    this.args.sendRank(option, rank);
    this.dMenu.close();
  }

  get rankLabel() {
    return this.args.rank === 0
      ? i18n("poll.options.ranked_choice.abstain")
      : this.args.rank;
  }

  <template>
    <DMenu @onRegisterApi={{this.onRegisterApi}}>
      <:trigger>
        <span class="d-button-label">
          {{this.rankLabel}}
        </span>
        {{dIcon "angle-down"}}
      </:trigger>
      <:content>
        <DDropdownMenu as |dropdown|>
          {{#each @rankedChoiceDropdownContent as |content|}}
            <dropdown.item>
              <DButton
                @translatedLabel={{content.name}}
                class="btn-transparent poll-option-dropdown"
                @action={{fn this.selectRank @option.id content.id}}
              />
            </dropdown.item>
          {{/each}}
        </DDropdownMenu>
      </:content>
    </DMenu>
  </template>
}
