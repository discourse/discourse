import Component from "@glimmer/component";
import { or } from "truth-helpers";

export default class PostMenuButtonWrapper extends Component {
  get shouldRender() {
    if (this.args.buttonConfig.delegateShouldRenderToTemplate) {
      return;
    }

    return this.args.buttonConfig.shouldRender(this.args);
  }

  <template>
    {{#if (or @buttonConfig.delegateShouldRenderToTemplate this.shouldRender)}}
      <@buttonConfig.Component
        class="btn-flat"
        @alwaysShow={{@buttonConfig.alwaysShow this.args}}
        @buttonActions={{@buttonActions}}
        @context={{@context}}
        @post={{@post}}
        @shouldRender={{this.shouldRender}}
        @showLabel={{@showLabel.showLabel this.args}}
      />
    {{/if}}
  </template>
}
