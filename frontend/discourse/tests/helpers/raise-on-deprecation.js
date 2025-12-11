import { registerDeprecationHandler } from "@ember/debug";
import { isEmpty } from "@ember/utils";
import QUnit from "qunit";
import DeprecationWorkflow from "discourse/deprecation-workflow";
import { registerDeprecationHandler as registerDiscourseDeprecationHandler } from "discourse/lib/deprecated";
import identifySource, { consolePrefix } from "discourse/lib/source-identifier";

let disabled = false;
let disabledQUnitResult = false;

const preInstalledPlugins = new Set();

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

function isPreInstalledPlugin(name) {
  if (preInstalledPlugins.has(name)) {
    return true;
  }

  const isPreinstalled = !!document.querySelector(
    `script[data-discourse-plugin="${name}"][data-preinstalled="true"]`
  );

  if (isPreinstalled) {
    preInstalledPlugins.add(name);
  }

  return isPreinstalled;
}

function skipDeprecationInPlugin(source) {
  if (!source) {
    return false;
  }

  if (source.type !== "plugin") {
    return false;
  }

  return !isPreInstalledPlugin(source?.name);
}

function raiseDeprecationError(message, options) {
  const source = options?.source ?? identifySource();

  if (skipDeprecationInPlugin(source)) {
    return;
  }

  const prefix = consolePrefix(null, source);
  const from = isEmpty(prefix)
    ? ""
    : ` FROM ${prefix.substring(1, prefix.length - 1)}`;

  message = `DEPRECATION${from}: ${message} (deprecation id: ${options.id})\n\nCore and all tre preinstalled plugins tests runs must be deprecation-free. Use ember-deprecation-workflow to silence unresolved deprecations.`;

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
