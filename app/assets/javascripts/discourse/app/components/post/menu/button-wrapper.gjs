import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { or } from "truth-helpers";
import { showAlert } from "../../../lib/post-action-feedback";

export default class PostMenuButtonWrapper extends Component {
  #element;

  get delegateShouldRenderToTemplate() {
    return this.args.buttonConfig.delegateShouldRenderToTemplate(this.args);
  }

  get shouldRender() {
    if (this.delegateShouldRenderToTemplate) {
      return;
    }

    return this.args.buttonConfig.shouldRender(this.args);
  }

  @action
  setElement(element) {
    this.#element = element;
  }

  @action
  sharedBehaviorOnClick(event) {
    event.currentTarget?.blur();
  }

  @action
  showFeedback(messageKey) {
    if (this.#element) {
      showAlert(this.args.post.id, this.args.buttonConfig.key, messageKey, {
        actionBtn: this.#element,
      });
    }
  }

  <template>
    {{#if (or this.shouldRender this.delegateShouldRenderToTemplate)}}
      <@buttonConfig.Component
        class="btn-flat"
        @buttonActions={{@buttonActions}}
        @hidden={{@buttonConfig.hidden this.args}}
        @post={{@post}}
        @shouldRender={{this.shouldRender}}
        @showFeedback={{this.showFeedback}}
        @showLabel={{@showLabel.showLabel this.args}}
        @state={{@state}}
        {{didInsert this.setElement}}
        {{on "click" this.sharedBehaviorOnClick}}
      />
    {{/if}}
  </template>
}
