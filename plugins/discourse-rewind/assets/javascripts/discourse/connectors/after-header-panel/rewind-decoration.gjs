import Component from "@glimmer/component";
import { service } from "@ember/service";
import bodyClass from "discourse/helpers/body-class";

export default class AvatarDecorator extends Component {
  @service currentUser;
  @service rewind;

  get showDecorator() {
    return (
      this.currentUser?.is_rewind_active &&
      !this.rewind.dismissed &&
      !this.rewind.disabled
    );
  }

  <template>
    {{#if this.showDecorator}}
      {{bodyClass "rewind-notification-active"}}
    {{/if}}
  </template>
}
