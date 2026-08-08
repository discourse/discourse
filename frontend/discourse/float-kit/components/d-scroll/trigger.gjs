import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSheetTrigger from "discourse/float-kit/components/d-sheet/trigger";

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

    if (pressEvent.forceFocus) {
      pressEvent.nativeEvent.currentTarget?.focus({ preventScroll: true });
    }

    if (pressEvent.runAction && this.executeAction()) {
      pressEvent.changeDefault({ forceFocus: false, runAction: false });
      return;
    }

    this.args.onClick?.(pressEvent.nativeEvent);
    pressEvent.changeDefault({ forceFocus: false, runAction: false });
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
      {{yield (hash handlePress=this.handlePress)}}
    {{else}}
      <DSheetTrigger @onPress={{this.handlePress}} ...attributes>
        {{yield}}
      </DSheetTrigger>
    {{/if}}
  </template>
}
