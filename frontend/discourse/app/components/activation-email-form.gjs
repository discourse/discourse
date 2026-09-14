import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";

export default class ActivationEmailForm extends Component {
  @action
  newEmailChanged(event) {
    this.args.updateNewEmail(event.target.value);
  }

  <template>
    <p>{{i18n "login.provide_new_email"}}</p>
    <input
      class="activate-new-email"
      type="text"
      value={{@email}}
      {{on "input" this.newEmailChanged}}
    />
  </template>
}
