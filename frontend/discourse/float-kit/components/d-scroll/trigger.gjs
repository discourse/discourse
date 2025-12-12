import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";

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
  handlePress(_, event) {
    const defaultBehavior = { forceFocus: true, runAction: true };

    if (this.args.onPress) {
      if (typeof this.args.onPress === "function") {
        const customEvent = {
          changeDefault: (changedBehavior) => {
            Object.assign(defaultBehavior, changedBehavior);
          },
          forceFocus: defaultBehavior.forceFocus,
          runAction: defaultBehavior.runAction,
          nativeEvent: event,
        };
        this.args.onPress(customEvent);
      } else if (typeof this.args.onPress === "object") {
        Object.assign(defaultBehavior, this.args.onPress);
      }
    }

    if (defaultBehavior.forceFocus && event.currentTarget) {
      event.currentTarget.focus({ preventScroll: true });
    }

    if (defaultBehavior.runAction && this.args.action && this.args.controller) {
      this.executeAction();
    }

    if (this.args.onClick) {
      this.args.onClick(event);
    }
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
      <DButton
        @action={{this.handlePress}}
        @forwardEvent={{true}}
        ...attributes
      >
        {{yield}}
      </DButton>
    {{/if}}
  </template>
}
