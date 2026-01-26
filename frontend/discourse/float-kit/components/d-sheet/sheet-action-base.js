import Component from "@glimmer/component";
import { service } from "@ember/service";
import {
  getActionType,
  getStepDetent,
  getStepDirection,
} from "discourse/float-kit/lib/action-utils";
import { processBehavior } from "discourse/float-kit/lib/behavior-handler";

export default class SheetActionBase extends Component {
  @service sheetRegistry;

  handleClick = (event) => {
    const behavior = processBehavior({
      nativeEvent: event,
      defaultBehavior: { forceFocus: true, runAction: true },
      handler: this.args.onPress,
    });

    if (behavior.forceFocus) {
      event.currentTarget?.focus({ preventScroll: true });
    }

    if (!behavior.runAction) {
      return;
    }

    this.executeAction();
  };

  get defaultAction() {
    return "present";
  }

  get targetRoot() {
    if (this.args.forComponent) {
      return this.sheetRegistry.getRootByComponentId(this.args.forComponent);
    }
    return undefined;
  }

  get sheet() {
    return this.targetRoot?.sheet ?? this.args.sheet;
  }

  get triggerAction() {
    return this.args.action ?? this.defaultAction;
  }

  get actionType() {
    return getActionType(this.triggerAction);
  }

  get stepDirection() {
    return getStepDirection(this.triggerAction);
  }

  get stepDetent() {
    return getStepDetent(this.triggerAction);
  }

  get sheetId() {
    return this.sheet?.id;
  }

  executeStepAction() {
    if (this.stepDetent !== undefined) {
      this.sheet?.stepToDetent(this.stepDetent);
    } else if (this.stepDirection === "down") {
      this.sheet?.stepDown();
    } else {
      this.sheet?.step();
    }
  }
}
