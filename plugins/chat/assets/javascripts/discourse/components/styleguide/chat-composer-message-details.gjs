import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { optionalRequire } from "discourse/lib/utilities";
import ChatComposerMessageDetails from "discourse/plugins/chat/discourse/components/chat-composer-message-details";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

const StyleguideComponent = optionalRequire(
  "discourse/plugins/styleguide/discourse/components/styleguide/component"
);
const Controls = optionalRequire(
  "discourse/plugins/styleguide/discourse/components/styleguide/controls"
);
const Row = optionalRequire(
  "discourse/plugins/styleguide/discourse/components/styleguide/controls/row"
);
const StyleguideExample = optionalRequire(
  "discourse/plugins/styleguide/discourse/components/styleguide-example"
);

export default class ChatStyleguideChatComposerMessageDetails extends Component {
  @service site;
  @service session;
  @service keyValueStore;
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
