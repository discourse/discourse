import Component from "@glimmer/component";
import { service } from "@ember/service";
import {
  getActionType,
  getStepDetent,
  getStepDirection,
} from "discourse/float-kit/lib/action-utils";
import { processBehavior } from "discourse/float-kit/lib/behavior-handler";

/**
 * Base class for sheet action components (triggers, handles).
 * Provides shared logic for resolving sheet targets, parsing action
 * configurations, and handling click events with customizable behavior.
 *
 * @extends Component
 */
export default class SheetActionBase extends Component {
  /** @type {import("discourse/float-kit/services/sheet-registry").default} */
  @service sheetRegistry;

  /**
   * Handles click events with configurable behavior via the onPress arg.
   * Optionally forces focus and runs the configured action.
   *
   * @param {MouseEvent} event - The native click event
   */
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

  /**
   * The default action type when no action arg is provided.
   * Subclasses override this to change the default (e.g. "step" for handles).
   *
   * @type {string}
   */
  get defaultAction() {
    return "present";
  }

  /**
   * Resolves the Root component via the forComponent arg using the sheet registry.
   *
   * @type {Object|undefined}
   */
  get targetRoot() {
    if (this.args.forComponent) {
      return this.sheetRegistry.getRootByComponentId(this.args.forComponent);
    }
    return undefined;
  }

  /**
   * The sheet controller instance, resolved from the target Root or the sheet arg.
   *
   * @type {Object|undefined}
   */
  get sheet() {
    return this.targetRoot?.sheet ?? this.args.sheet;
  }

  /**
   * The resolved action configuration, falling back to the default action.
   *
   * @type {string|Object}
   */
  get triggerAction() {
    return this.args.action ?? this.defaultAction;
  }

  /**
   * The parsed action type string from the action configuration.
   *
   * @type {string}
   */
  get actionType() {
    return getActionType(this.triggerAction);
  }

  /**
   * The parsed step direction from the action configuration.
   *
   * @type {string}
   */
  get stepDirection() {
    return getStepDirection(this.triggerAction);
  }

  /**
   * The parsed target detent index from the action configuration.
   *
   * @type {number|undefined}
   */
  get stepDetent() {
    return getStepDetent(this.triggerAction);
  }

  /**
   * The ID of the resolved sheet, used for aria-controls.
   *
   * @type {string|undefined}
   */
  get sheetId() {
    return this.sheet?.id;
  }

  /**
   * Executes the configured action on the sheet. This method must be
   * implemented by subclasses to handle specific action types.
   * Called by handleClick when runAction behavior is enabled.
   */
  executeAction() {
    // Implemented by subclasses
  }

  /**
   * Executes a step action on the sheet. Steps to a specific detent if
   * configured, otherwise steps down or up based on the step direction.
   */
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
