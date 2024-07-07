import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import icon from "discourse-common/helpers/d-icon";
import I18n from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

export default class PollOptionsDropdownComponent extends Component {
  @tracked rank;

  constructor() {
    super(...arguments);
    this.rank = this.args.rank;
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  selectRank(option, rank) {
    this.args.sendRank(option, rank);
    this.rank =
      rank === 0 ? I18n.t("poll.options.ranked_choice.abstain") : rank;
    this.dMenu.close();
  }

  get rankLabel() {
    return this.rank === 0
      ? I18n.t("poll.options.ranked_choice.abstain")
      : this.rank;
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
