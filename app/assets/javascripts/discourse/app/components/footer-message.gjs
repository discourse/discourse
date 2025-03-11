import Component from "@ember/component";
import { classNames } from "@ember-decorators/component";

@classNames("footer-message")
export default class FooterMessage extends Component {}
<h3>
  {{this.message}}
  {{yield}}
</h3>
{{#if this.education}}
  <div class="education">
    {{html-safe this.education}}
  </div>
{{/if}}