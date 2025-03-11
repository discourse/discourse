import Component from "@ember/component";
import { classNames } from "@ember-decorators/component";
import htmlSafe from "discourse/helpers/html-safe";

@classNames("footer-message")
export default class FooterMessage extends Component {
  <template>
    <h3>
      {{this.message}}
      {{yield}}
    </h3>
    {{#if this.education}}
      <div class="education">
        {{htmlSafe this.education}}
      </div>
    {{/if}}
  </template>
}
