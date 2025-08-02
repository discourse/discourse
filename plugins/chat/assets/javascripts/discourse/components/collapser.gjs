import Component from "@ember/component";
import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

@tagName("")
export default class Collapser extends Component {
  collapsed = false;
  header = null;
  onToggle = null;

  @action
  open() {
    this.set("collapsed", false);
    this.onToggle?.(false);
  }

  @action
  close() {
    this.set("collapsed", true);
    this.onToggle?.(true);
  }

  <template>
    <div class="chat-message-collapser-header">
      {{this.header}}

      {{#if this.collapsed}}
        <DButton
          @action={{this.open}}
          @icon="caret-right"
          class="chat-message-collapser-button chat-message-collapser-closed"
        />
      {{else}}
        <DButton
          @action={{this.close}}
          @icon="caret-down"
          class="chat-message-collapser-button chat-message-collapser-opened"
        />
      {{/if}}
    </div>

    <div
      class={{concatClass
        "chat-message-collapser-body"
        (if this.collapsed "hidden")
      }}
    >
      {{yield this.collapsed}}
    </div>
  </template>
}
