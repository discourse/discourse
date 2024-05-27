import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import routeAction from "discourse/helpers/route-action";
import icon from "discourse-common/helpers/d-icon";
import PollOptionIrv from "./poll-option-irv";

export default class PollOptionsComponent extends Component {
  @service currentUser;

  isChosen = (option) => {
    return this.args.votes.includes(option.id);
  };

  get classes() {
    return this.args.isIrv ? "irv-poll-options" : "";
  }

  @action
  sendClick(option) {
    this.args.sendOptionSelect(option);
  }

  @action
  sendRank(option, rank = 0) {
    this.args.sendOptionSelect(option, rank);
  }
  <template>
    <ul class={{this.classes}}>
      {{#each @options as |option|}}
        {{#if @isIrv}}
          <PollOptionIrv
            @option={{option}}
            @irvDropdownContent={{@irvDropdownContent}}
            @sendRank={{this.sendRank}}
          />
        {{else}}
          <li tabindex="0" data-poll-option-id={{option.id}}>
            {{#if this.currentUser}}
              <button {{on "click" (fn this.sendClick option)}}>
                {{#if (this.isChosen option)}}
                  {{#if @isCheckbox}}
                    {{icon "far-check-square"}}
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
                <span class="option-text">{{option.html}}</span>
              </button>
            {{else}}
              <button onclick={{routeAction "showLogin"}}>
                {{#if (this.isChosen option)}}
                  {{#if @isCheckbox}}
                    {{icon "far-check-square"}}
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
                <span class="option-text">{{option.html}}</span>
              </button>
            {{/if}}
          </li>
        {{/if}}
      {{/each}}
    </ul>
  </template>
}
