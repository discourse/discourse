import Component from "@ember/component";
import { schedule } from "@ember/runloop";
import $ from "jquery";
import dIcon from "discourse/helpers/d-icon";
import iN from "discourse/helpers/i18n";

export default class LinkToInput extends Component {
  <template>
    {{#if this.showInput}}
      {{yield}}
    {{else}}
      <a href>
        {{#if this.key}}
          {{iN this.key}}
        {{/if}}
        {{#if this.icon}}
          {{dIcon this.icon}}
        {{/if}}
      </a>
    {{/if}}
  </template>
  showInput = false;

  click() {
    this.onClick();

    schedule("afterRender", () => {
      $(this.element).find("input").focus();
    });

    return false;
  }
}
