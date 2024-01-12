import Component from "@glimmer/component";
import concatClass from "discourse/helpers/concat-class";
import ChatFormRow from "discourse/plugins/chat/discourse/components/chat/form/row";

export default class ChatFormSection extends Component {
  get yieldableArgs() {
    return { row: ChatFormRow };
  }

  <template>
    <div class={{concatClass "chat-form__section" @extraClass}} ...attributes>
      {{#if @title}}
        <div class="chat-form__section-title">
          {{@title}}
        </div>
      {{/if}}

      <div class="chat-form__section-content">
        {{yield this.yieldableArgs}}
      </div>
    </div>
  </template>
}
