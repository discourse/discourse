import { registerDeprecationHandler } from "@ember/debug";
import { isEmpty } from "@ember/utils";
import QUnit from "qunit";
import DeprecationWorkflow from "discourse/deprecation-workflow";
import { registerDeprecationHandler as registerDiscourseDeprecationHandler } from "discourse/lib/deprecated";
import identifySource, { consolePrefix } from "discourse/lib/source-identifier";

let disabled = false;
let disabledQUnitResult = false;

/**
 * Configures deprecation handlers to raise errors when deprecations occur in tests.
 * This ensures core and preinstalled plugins remain deprecation-free.
 */
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

/**
 * Raises a deprecation error in QUnit tests, including source information.
 *
 * @param {string} message - The deprecation message
 * @param {Object} options - Deprecation options including id and source
 */
function raiseDeprecationError(message, options) {
  const source = options?.source ?? identifySource();

  const prefix = consolePrefix(null, source);
  const from = isEmpty(prefix)
    ? ""
    : ` FROM ${prefix.substring(1, prefix.length - 1)}`;

  message = `DEPRECATION${from}: ${message} (deprecation id: ${options.id})\n\nCore and all the preinstalled plugins tests runs must be deprecation-free. Use ember-deprecation-workflow to silence unresolved deprecations.`;

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
