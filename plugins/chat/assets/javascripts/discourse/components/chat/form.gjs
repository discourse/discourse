import Component from "@glimmer/component";
import ChatFormSection from "discourse/plugins/chat/discourse/components/chat/form/section";

export default class ChatForm extends Component {
  <template>
    <div class="chat-form">
      {{yield this.yieldableArgs}}
    </div>
  </template>

  get yieldableArgs() {
    return { section: ChatFormSection };
  }
}
