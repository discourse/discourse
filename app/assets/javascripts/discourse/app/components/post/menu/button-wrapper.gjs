import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { or } from "truth-helpers";

export default class PostMenuButtonWrapper extends Component {
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
  sharedBehaviorOnClick(event) {
    event.currentTarget?.blur();
  }

  <template>
    {{#if (or this.shouldRender this.delegateShouldRenderToTemplate)}}
      <@buttonConfig.Component
        class="btn-flat"
        @collapsedByDefault={{@buttonConfig.collapsedByDefault this.args}}
        @buttonActions={{@buttonActions}}
        @post={{@post}}
        @shouldRender={{this.shouldRender}}
        @showLabel={{@showLabel.showLabel this.args}}
        @state={{@state}}
        {{on "click" this.sharedBehaviorOnClick}}
      />
    {{/if}}
  </template>
}
