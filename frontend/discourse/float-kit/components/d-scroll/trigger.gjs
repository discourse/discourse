import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSheetTrigger from "discourse/float-kit/components/d-sheet/trigger";

/**
 * DScroll.Trigger - A button that triggers scroll actions.
 *
 * @component
 * @param {Object} @controller - The scroll controller instance
 * @param {Object} @action - Action to execute: { type: "scroll-to" | "scroll-by", progress?, distance?, animationSettings? }
 * @param {Function|Object} @onPress - Press event handler or options: { forceFocus?: boolean, runAction?: boolean }
 * @param {Function} @onClick - Click handler invoked after the action logic
 */
export default class DScrollTrigger extends Component {
  @action
  handlePress(pressEvent) {
    if (this.args.onPress) {
      if (typeof this.args.onPress === "function") {
        this.args.onPress(pressEvent);
      } else {
        pressEvent.changeDefault(this.args.onPress);
      }
    }

    if (pressEvent.runAction && this.args.action && this.args.controller) {
      this.executeAction();
    }

    if (this.args.onClick) {
      this.args.onClick(pressEvent.nativeEvent);
    }

    pressEvent.changeDefault({ runAction: false });
  }

  executeAction() {
    const { action, controller } = this.args;
    if (!action || !controller) {
      return;
    }

    const { type, progress, distance, animationSettings } = action;

    if (type === "scroll-to") {
      controller.scrollTo({ progress, distance, animationSettings });
    } else if (type === "scroll-by") {
      controller.scrollBy({ progress, distance, animationSettings });
    }
  }

  <template>
    {{#if @asChild}}
      {{yield (hash handlePress=this.handlePress)}}
    {{else}}
      <DSheetTrigger @onPress={{this.handlePress}} ...attributes>
        {{yield}}
      </DSheetTrigger>
    {{/if}}
  </template>
}

