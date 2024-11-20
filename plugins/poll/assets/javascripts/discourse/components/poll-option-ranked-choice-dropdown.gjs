import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import icon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

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
        {{icon "angle-down"}}
      </:trigger>
      <:content>
        <DropdownMenu as |dropdown|>
          {{#each @rankedChoiceDropdownContent as |content|}}
            <dropdown.item>
              <DButton
                @translatedLabel={{content.name}}
                class="btn-transparent poll-option-dropdown"
                @action={{fn this.selectRank @option.id content.id}}
              />
            </dropdown.item>
          {{/each}}
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
