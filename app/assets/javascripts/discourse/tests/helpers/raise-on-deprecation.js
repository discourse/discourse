import { registerDeprecationHandler } from "@ember/debug";
import { registerDeprecationHandler as registerDiscourseDeprecationHandler } from "discourse-common/lib/deprecated";
import QUnit from "qunit";

let disabled = false;

export function configureRaiseOnDeprecation() {
  const workflows = window.deprecationWorkflow?.config?.workflow;
  if (!workflows) {
    return;
  }

  if (window.EmberENV.RAISE_ON_DEPRECATION !== undefined) {
    return;
  }

  registerDeprecationHandler((message, options, next) => {
    if (disabled || workflows.find((w) => w.matchId === options.id)) {
      return next(message, options);
    }
    raiseDeprecationError(message, options);
  });

  registerDiscourseDeprecationHandler((message, options) => {
    if (disabled || workflows.find((w) => w.matchId === options?.id)) {
      return;
    }
    raiseDeprecationError(message, options);
  });
}

function raiseDeprecationError(message, options) {
  message = `DEPRECATION IN CORE TEST: ${message} (deprecation id: ${options.id})\n\nCore test runs must be deprecation-free. Use ember-deprecation-workflow to silence unresolved deprecations.`;
  if (QUnit.config.current) {
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
