import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import ChatComposerMessageDetails from "discourse/plugins/chat/discourse/components/chat-composer-message-details";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import StyleguideComponent from "discourse/plugins/styleguide/discourse/components/styleguide/component" with {
  discourseImport: "optional",
};
import Controls from "discourse/plugins/styleguide/discourse/components/styleguide/controls" with {
  discourseImport: "optional",
};
import Row from "discourse/plugins/styleguide/discourse/components/styleguide/controls/row" with {
  discourseImport: "optional",
};
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example" with {
  discourseImport: "optional",
};

export default class ChatStyleguideChatComposerMessageDetails extends Component {
  @service currentUser;

  @cached
  get message() {
    return new ChatFabricators(getOwner(this)).message({
      user: this.currentUser,
    });
  }

  @action
  toggleMode() {
    if (this.message.editing) {
      this.message.editing = false;
      this.message.inReplyTo = new ChatFabricators(getOwner(this)).message();
    } else {
      this.message.editing = true;
      this.message.inReplyTo = null;
    }
  }

  <template>
    <StyleguideExample @title="<ChatComposerMessageDetails>">
      <StyleguideComponent>
        <ChatComposerMessageDetails @message={{this.message}} />
      </StyleguideComponent>

      <Controls>
        <Row @name="Mode">
          {{#if this.message.editing}}
            <DButton @action={{this.toggleMode}} @translatedLabel="Reply" />
          {{else}}
            <DButton @action={{this.toggleMode}} @translatedLabel="Editing" />
          {{/if}}
        </Row>
      </Controls>
    </StyleguideExample>
  </template>
}
