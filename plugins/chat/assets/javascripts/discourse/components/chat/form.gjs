import Component from "@glimmer/component";
import ChatFormSection from "discourse/plugins/chat/discourse/components/chat/form/section";

export default class ChatForm extends Component {
  get yieldableArgs() {
    return { section: ChatFormSection };
  }

  <template>
    <div class="chat-form">
      {{yield this.yieldableArgs}}
    </div>
  </template>
}
