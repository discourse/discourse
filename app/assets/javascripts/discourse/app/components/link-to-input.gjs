import Component from "@ember/component";
import { schedule } from "@ember/runloop";
import $ from "jquery";

export default class LinkToInput extends Component {
  showInput = false;

  click() {
    this.onClick();

    schedule("afterRender", () => {
      $(this.element).find("input").focus();
    });

    return false;
  }
}

{{#if this.showInput}}
  {{yield}}
{{else}}
  <a href>
    {{#if this.key}}
      {{i18n this.key}}
    {{/if}}
    {{#if this.icon}}
      {{d-icon this.icon}}
    {{/if}}
  </a>
{{/if}}