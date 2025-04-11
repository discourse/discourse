import Component from "@ember/component";
import { classNames } from "@ember-decorators/component";
import { eq } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";

@classNames("row")
export default class AdminFormRow extends Component {
  <template>
    <div class="form-element label-area">
      {{#if this.label}}
        <label
          class={{concatClass (if (eq @type "checkbox") "checkbox-label")}}
        >{{i18n this.label}}</label>
      {{else}}
        &nbsp;
      {{/if}}
    </div>
    <div class="form-element input-area">
      {{#if this.wrapLabel}}
        <label
          class={{concatClass (if (eq @type "checkbox") "checkbox-label")}}
        >{{yield}}</label>
      {{else}}
        {{yield}}
      {{/if}}
    </div>
  </template>
}
