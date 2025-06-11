import Component from "@ember/component";
import { classNames } from "@ember-decorators/component";

@classNames("footer-message")
export default class FooterMessage extends Component {
  <template>
    {{#if this.message}}
      <h3>
        {{this.message}}
        {{yield to="messageDetails"}}
      </h3>
    {{/if}}

    {{yield to="afterMessage"}}
  </template>
}
