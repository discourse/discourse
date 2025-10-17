/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { classNames } from "@ember-decorators/component";

@classNames("footer-message")
export default class FooterMessage extends Component {
  <template>
    <h3>
      {{yield to="messageDetails"}}
    </h3>

    {{yield to="afterMessage"}}
  </template>
}
