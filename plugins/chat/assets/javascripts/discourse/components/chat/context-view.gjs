import Component from "@glimmer/component";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";

export default class ChatContextView extends Component {
  @service chatStateManager;

  registerSlot = modifier((element) =>
    this.chatStateManager.registerContextDrawerSlot(element)
  );

  <template>
    <div class="chat-context-view" {{this.registerSlot}}></div>
  </template>
}
