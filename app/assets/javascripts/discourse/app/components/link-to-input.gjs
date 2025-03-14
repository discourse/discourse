import Component from "@ember/component";
import { schedule } from "@ember/runloop";
import $ from "jquery";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class LinkToInput extends Component {
  showInput = false;

  click() {
    this.onClick();

    schedule("afterRender", () => {
      $(this.element).find("input").focus();
    });

    return false;
  }

  <template>
    {{#if this.showInput}}
      {{yield}}
    {{else}}
      <a href>
        {{#if this.key}}
          {{i18n this.key}}
        {{/if}}
        {{#if this.icon}}
          {{icon this.icon}}
        {{/if}}
      </a>
    {{/if}}
  </template>
}
