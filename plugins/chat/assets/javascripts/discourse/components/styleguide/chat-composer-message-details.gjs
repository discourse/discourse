import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

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
}

<StyleguideExample @title="<ChatComposerMessageDetails>">
  <Styleguide::Component>
    <ChatComposerMessageDetails @message={{this.message}} />
  </Styleguide::Component>

  <Styleguide::Controls>
    <Styleguide::Controls::Row @name="Mode">
      {{#if this.message.editing}}
        <DButton @action={{this.toggleMode}} @translatedLabel="Reply" />
      {{else}}
        <DButton @action={{this.toggleMode}} @translatedLabel="Editing" />
      {{/if}}
    </Styleguide::Controls::Row>
  </Styleguide::Controls>
</StyleguideExample>