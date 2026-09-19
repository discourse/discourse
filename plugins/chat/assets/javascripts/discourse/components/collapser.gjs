import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class Collapser extends Component {
  @tracked collapsed = false;

  @action
  open() {
    this.collapsed = false;
    this.args.onToggle?.(false);
  }

  @action
  close() {
    this.collapsed = true;
    this.args.onToggle?.(true);
  }

  <template>
    <div class="chat-message-collapser-header">
      {{@header}}

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
