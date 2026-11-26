import Component from "@glimmer/component";
import { uniqueId } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import routeAction from "discourse/helpers/route-action";
import DButton from "discourse/ui-kit/d-button";
import dElement from "discourse/ui-kit/helpers/d-element";
import decoratePollOption from "../modifiers/decorate-poll-option.js";
import PollOptionRankedChoiceDropdown from "./poll-option-ranked-choice-dropdown.gjs";

export default class PollOptionsComponent extends Component {
  @service currentUser;
  @service siteSettings;

  @action
  sendRank(option, rank = 0) {
    this.args.sendRank(option, rank);
  }

  <template>
    {{#let (uniqueId) as |labelId|}}
      {{! TODO (select-kit-replacement-cleanup): Keep only the list item, without its own tab stop, after rollout. }}
      {{#let
        (dElement (if this.siteSettings.enable_new_select_controls "li" "div"))
        as |Row|
      }}
        <Row
          class="ranked-choice-poll-option"
          data-poll-option-id={{@option.id}}
          data-poll-option-rank={{@rank}}
          tabindex={{unless this.siteSettings.enable_new_select_controls "0"}}
        >
          {{#if this.currentUser}}
            <PollOptionRankedChoiceDropdown
              @labelId={{labelId}}
              @option={{@option}}
              @rank={{@rank}}
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
          <span
            class="option-text"
            id={{labelId}}
            {{decoratePollOption @option.html}}
          ></span>
        </Row>
      {{/let}}
    {{/let}}
  </template>
}
