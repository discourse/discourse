import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import icon from "discourse-common/helpers/d-icon";
import DropdownMenu from "discourse/components/dropdown-menu";
import DButton from "discourse/components/d-button";
import DMenu from "float-kit/components/d-menu";

export default class PollOptionsDropdownComponent extends Component {
  @tracked rank;

  constructor() {
    super(...arguments);
    this.rank =
      this.args.rank === 0
        ? I18n.t("poll.options.irv.abstain")
        : this.args.rank;
  }

  @action
  selectRank(option, rank) {
    this.args.sendRank(option, rank);
    this.rank = rank === 0 ? I18n.t("poll.options.irv.abstain") : rank;
  }

  <template>
    <DMenu>
      <:trigger>
        <span class="d-button-label">
          {{this.rank}}
        </span>
        {{icon "angle-down"}}
      </:trigger>
      <:content>
        <DropdownMenu as |dropdown|>
          {{#each @irvDropdownContent as |content|}}
            <dropdown.item>
              <DButton
                @translatedLabel={{content.name}}
                class="btn btn-transparent poll-option-dropdown"
                @action={{fn this.selectRank @option.id content.id}}
              />
            </dropdown.item>
          {{/each}}
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
