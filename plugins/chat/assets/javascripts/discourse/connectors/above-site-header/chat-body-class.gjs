import Component from "@glimmer/component";
import { service } from "@ember/service";
import bodyClass from "discourse/helpers/body-class";

export default class ChatBodyClass extends Component {
  @service chatStateManager;

  <template>
    {{#if this.chatStateManager.hasPreloadedChannels}}
      {{bodyClass "has-preloaded-chat-channels"}}
    {{/if}}
  </template>
}
