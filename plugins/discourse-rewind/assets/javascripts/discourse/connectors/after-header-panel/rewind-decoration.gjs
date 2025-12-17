import Component from "@glimmer/component";
import { service } from "@ember/service";
import bodyClass from "discourse/helpers/body-class";

export default class AvatarDecorator extends Component {
  @service rewind;

  get showDecorator() {
    return this.rewind.active && !this.rewind.dismissed && this.rewind.enabled;
  }

  <template>
    {{#if this.showDecorator}}
      {{bodyClass "rewind-notification-active"}}
    {{/if}}
  </template>
}
