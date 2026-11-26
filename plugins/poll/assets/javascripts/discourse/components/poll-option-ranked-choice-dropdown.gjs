import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { selectOption } from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

export default class PollOptionsDropdownComponent extends Component {
  @service siteSettings;

  get rankLabel() {
    return this.args.rank === 0
      ? i18n("poll.options.ranked_choice.abstain")
      : this.args.rank;
  }

  /**
   * The ranks as numbers, with the priority each end stands for as its description. Abstain keeps
   * its name.
   */
  get rankOptions() {
    const ranks = this.args.rankedChoiceDropdownContent;
    const lowest = ranks.length - 1;

    return ranks.map((rank) => {
      if (rank.id === 0) {
        return rank;
      }

      let description;
      if (rank.id === 1) {
        description = i18n("poll.options.ranked_choice.highest_priority");
      } else if (rank.id === lowest) {
        description = i18n("poll.options.ranked_choice.lowest_priority");
      }

      return selectOption(rank, { label: String(rank.id), description });
    });
  }

  @action
  changeRank(rank) {
    this.args.sendRank(this.args.option.id, rank);
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  selectRank(option, rank) {
    this.args.sendRank(option, rank);
    this.dMenu.close();
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
    {{#if this.siteSettings.enable_new_select_controls}}
      <DSelect
        class="ranked-choice-poll-option__rank"
        @ariaLabelledBy={{@labelId}}
        @contentClass="ranked-choice-poll-option__rank-content"
        @onChange={{this.changeRank}}
        @options={{this.rankOptions}}
        @required={{true}}
        @selectedIcon="check"
        @value={{@rank}}
        @variant="static"
      />
    {{else}}
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
                  class="btn-transparent poll-option-dropdown"
                  @action={{fn this.selectRank @option.id content.id}}
                  @translatedLabel={{content.name}}
                />
              </dropdown.item>
            {{/each}}
          </DDropdownMenu>
        </:content>
      </DMenu>
    {{/if}}
  </template>
}
