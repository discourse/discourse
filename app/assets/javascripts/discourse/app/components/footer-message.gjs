import Component from "@ember/component";
import { htmlSafe } from "@ember/template";
import { classNames } from "@ember-decorators/component";

@classNames("footer-message")
export default class FooterMessage extends Component {
  <template>
    {{#if this.message}}
      <h3>
        {{this.message}}
        {{yield to="message"}}
      </h3>
    {{/if}}
    {{#if this.education}}
      <div class="education">
        {{htmlSafe this.education}}
      </div>
    {{else}}
      {{yield to="education"}}
    {{/if}}
  </template>
}
