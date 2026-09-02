/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

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
          class="chat-message-collapser-button chat-message-collapser-closed"
          @action={{this.open}}
          @icon="angle-right"
        />
      {{else}}
        <DButton
          class="chat-message-collapser-button chat-message-collapser-opened"
          @action={{this.close}}
          @icon="angle-down"
        />
      {{/if}}
    </div>

    <div
      class={{dConcatClass
        "chat-message-collapser-body"
        (if this.collapsed "hidden")
      }}
    >
      {{yield this.collapsed}}
    </div>
  </template>
}
