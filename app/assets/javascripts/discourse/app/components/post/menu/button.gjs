import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";

export default class PostMenuButton extends Component {
  @cached // context can be expensive
  get context() {
    if (typeof this.args.button.context === "function") {
      return this.args.button.context();
    }

    return this.args.button.context;
  }

  get shouldRender() {
    if (typeof this.args.button.shouldRender === "function") {
      return this.args.button.shouldRender(this.args.post, this.context);
    }

    return this.args.button.shouldRender ?? true;
  }

  get showLabel() {
    return this.args.showLabel ?? this.args.button.showLabel;
  }

  <template>
    <@button.Component
      class="btn-flat"
      ...attributes
      @action={{@button.action}}
      @actionMode={{@button.actionMode}}
      @context={{this.context}}
      @post={{@post}}
      @secondaryAction={{@button.secondaryAction}}
      @shouldRender={{this.shouldRender}}
      @showLabel={{this.showLabel}}
    />
  </template>
}
