import Component from "@glimmer/component";
import { service } from "@ember/service";
import concatClass from "discourse/ui-kit/helpers/d-concat-class";
import outletAnimationModifier from "./d-sheet/outlet-animation-modifier";

export default class SheetStackOutlet extends Component {
  @service sheetStackRegistry;

  get stackId() {
    return this.args.stackId ?? this.args.forComponent;
  }

  get animationTarget() {
    const stackId = this.stackId;

    if (!stackId) {
      return null;
    }

    return {
      registerStackingAnimation: (animation) =>
        this.sheetStackRegistry.registerStackingAnimation(stackId, animation),
    };
  }

  get isAnimating() {
    const stackId = this.stackId;

    if (!stackId) {
      return false;
    }

    return this.sheetStackRegistry.getMergedStagingForStack(stackId) !== "none";
  }

  <template>
    <div
      data-d-sheet-stack={{concatClass
        "outlet"
        (if this.isAnimating "animating")
      }}
      {{outletAnimationModifier this.animationTarget null @stackingAnimation}}
      ...attributes
    >
      {{yield}}
    </div>
  </template>
}
