import Component from "@ember/component";
import { htmlSafe } from "@ember/template";
import { classNames } from "@ember-decorators/component";

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
