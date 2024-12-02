import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import concatClass from "discourse/helpers/concat-class";
import routeAction from "discourse/helpers/route-action";
import icon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";
import PollOptionRankedChoice from "./poll-option-ranked-choice";

export default class PollOptionsComponent extends Component {
  @service currentUser;

  isChosen = (option) => {
    return this.args.votes.includes(option.id);
  };

  @action
  sendClick(option) {
    this.args.sendOptionSelect(option);
  }

  @action
  sendRank(option, rank = 0) {
    this.args.sendOptionSelect(option, rank);
  }

  get rankedChoiceDropdownContent() {
    let rankedChoiceDropdownContent = [];

    rankedChoiceDropdownContent.push({
      id: 0,
      name: i18n("poll.options.ranked_choice.abstain"),
    });

    this.args.options.forEach((option, i) => {
      option.rank = 0;
      let priority = "";

      if (i === 0) {
        priority = ` ${i18n("poll.options.ranked_choice.highest_priority")}`;
      }

      if (i === this.args.options.length - 1) {
        priority = ` ${i18n("poll.options.ranked_choice.lowest_priority")}`;
      }

      rankedChoiceDropdownContent.push({
        id: i + 1,
        name: (i + 1).toString() + priority,
      });
    });

    return rankedChoiceDropdownContent;
  }

  <template>
    <ul
      class={{concatClass
        (if @isRankedChoice "ranked-choice-poll-options")
        "options"
      }}
    >
      {{#each @options key="rank" as |option|}}
        {{#if @isRankedChoice}}
          <PollOptionRankedChoice
            @option={{option}}
            @rankedChoiceDropdownContent={{this.rankedChoiceDropdownContent}}
            @sendRank={{this.sendRank}}
          />
        {{else}}
          <li data-poll-option-id={{option.id}}>
            {{#if this.currentUser}}
              <button {{on "click" (fn this.sendClick option)}}>
                {{#if (this.isChosen option)}}
                  {{#if @isCheckbox}}
                    {{icon "far-square-check"}}
                  {{else}}
                    {{icon "circle"}}
                  {{/if}}
                {{else}}
                  {{#if @isCheckbox}}
                    {{icon "far-square"}}
                  {{else}}
                    {{icon "far-circle"}}
                  {{/if}}
                {{/if}}
                <span class="option-text">{{htmlSafe option.html}}</span>
              </button>
            {{else}}
              <button onclick={{routeAction "showLogin"}}>
                {{#if (this.isChosen option)}}
                  {{#if @isCheckbox}}
                    {{icon "far-square-check"}}
                  {{else}}
                    {{icon "circle"}}
                  {{/if}}
                {{else}}
                  {{#if @isCheckbox}}
                    {{icon "far-square"}}
                  {{else}}
                    {{icon "far-circle"}}
                  {{/if}}
                {{/if}}
                <span class="option-text">{{htmlSafe option.html}}</span>
              </button>
            {{/if}}
          </li>
        {{/if}}
      {{/each}}
    </ul>
  </template>
}
