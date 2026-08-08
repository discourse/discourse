import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { service } from "@ember/service";
import mergeSheetStackAttributes from "../modifiers/merge-sheet-stack-attributes";
import outletAnimationModifier from "./d-sheet/outlet-animation-modifier";

export default class SheetStackOutlet extends Component {
  @service sheetStackRegistry;

  get stackId() {
    return this.args.stackId ?? this.args.forComponent;
  }

  @cached
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
      {{outletAnimationModifier this.animationTarget null @stackingAnimation}}
      ...attributes
      {{mergeSheetStackAttributes "outlet" (if this.isAnimating "animating")}}
    >
      {{yield}}
    </div>
  </template>
}
