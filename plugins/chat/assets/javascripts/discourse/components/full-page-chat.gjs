import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { service } from "@ember/service";
import ChatChannel from "./chat-channel";

export default class FullPageChat extends Component {
  @service chat;

  <template>
    {{#each (array @channel) as |channel|}}
      <ChatChannel @channel={{channel}} @targetMessageId={{@targetMessageId}} />
    {{/each}}
  </template>
}
