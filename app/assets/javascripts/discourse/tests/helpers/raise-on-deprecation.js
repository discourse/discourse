import { registerDeprecationHandler } from "@ember/debug";
import QUnit from "qunit";
import DeprecationWorkflow from "discourse/deprecation-workflow";
import { registerDeprecationHandler as registerDiscourseDeprecationHandler } from "discourse/lib/deprecated";

let disabled = false;
let disabledQUnitResult = false;

export function configureRaiseOnDeprecation() {
  if (window.EmberENV.RAISE_ON_DEPRECATION !== undefined) {
    return;
  }

  registerDeprecationHandler((message, options, next) => {
    if (
      disabled ||
      !DeprecationWorkflow.shouldThrow(options.id, true) ||
      options.id.startsWith("ember-metal.")
    ) {
      return next(message, options);
    }
    raiseDeprecationError(message, options);
  });

  registerDiscourseDeprecationHandler((message, options) => {
    if (disabled || !DeprecationWorkflow.shouldThrow(options?.id, true)) {
      return;
    }
    raiseDeprecationError(message, options);
  });
}

function raiseDeprecationError(message, options) {
  message = `DEPRECATION IN CORE TEST: ${message} (deprecation id: ${options.id})\n\nCore test runs must be deprecation-free. Use ember-deprecation-workflow to silence unresolved deprecations.`;
  if (QUnit.config.current && !disabledQUnitResult) {
    QUnit.assert.pushResult({
      result: false,
      message,
    });
  }
  throw new Error(message);
}

export function disableRaiseOnDeprecation() {
  disabled = true;
}

export function enableRaiseOnDeprecation() {
  disabled = false;
}

export function disableRaiseOnDeprecationQUnitResult() {
  disabledQUnitResult = true;
}

export function enableRaiseOnDeprecationQUnitResult() {
  disabledQUnitResult = false;
}
