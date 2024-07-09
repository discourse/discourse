import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import routeAction from "discourse/helpers/route-action";
import icon from "discourse-common/helpers/d-icon";

export default class PollOptionsComponent extends Component {
  @service currentUser;

  isChosen = (option) => {
    return this.args.votes.includes(option.id);
  };

  @action
  sendClick(option) {
    this.args.sendOptionSelect(option);
  }

  <template>
    <ul>
      {{#each @options as |option|}}
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
              <span class="option-text">{{htmlSafe option.html}}</span>
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
              <span class="option-text">{{htmlSafe option.html}}</span>
            </button>
          {{/if}}
        </li>
      {{/each}}
    </ul>
  </template>
}
