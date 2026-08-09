import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { processBehavior } from "discourse/float-kit/lib/behavior-handler";

export default class DScrollTrigger extends Component {
  @action
  handleClick(event) {
    const behavior = processBehavior({
      nativeEvent: event,
      defaultBehavior: { forceFocus: true, runAction: true },
      handler: this.args.onPress,
    });

    if (behavior.forceFocus) {
      event.currentTarget?.focus({ preventScroll: true });
    }

    if (behavior.runAction && this.executeAction()) {
      return;
    }

    this.args.onClick?.(event);
  }

  executeAction() {
    const { action: scrollAction, controller } = this.args;
    if (!scrollAction || !controller) {
      return false;
    }

    const { type, progress, distance, animationSettings } = scrollAction;

    if (type === "scroll-to") {
      controller.scrollTo({ progress, distance, animationSettings });
      return true;
    } else if (type === "scroll-by") {
      controller.scrollBy({ progress, distance, animationSettings });
      return true;
    }

    return false;
  }

  <template>
    {{#if @asChild}}
      {{yield (hash handlePress=this.handleClick)}}
    {{else}}
      <button type="button" {{on "click" this.handleClick}} ...attributes>
        {{yield}}
      </button>
    {{/if}}
  </template>
}
