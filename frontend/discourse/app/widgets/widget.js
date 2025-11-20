import deprecated from "discourse/lib/deprecated";
import { consolePrefix } from "discourse/lib/source-identifier";

export const WIDGET_DEPRECATION_OPTIONS = {
  since: "v3.5.0.beta8-dev",
  id: "discourse.widgets-end-of-life",
  url: "https://meta.discourse.org/t/375332/1",
};

export const POST_STREAM_DEPRECATION_OPTIONS = {
  since: "v3.5.0.beta1-dev",
  id: "discourse.post-stream-widget-overrides",
  url: "https://meta.discourse.org/t/372063/1",
};

export const WIDGET_DECOMMISSION_OPTIONS = {
  since: "v3.6.0.beta3-latest",
  id: "discourse.widgets-decommissioned",
  url: "https://meta.discourse.org/t/375332/1",
};

function warnWidgetsDecommissioned() {
  deprecated(
    `"The widget rendering system has been decommissioned and all related components and APIs are no-longer operational.`,
    WIDGET_DECOMMISSION_OPTIONS
  );
}

class DummyWidget {
  constructor() {
    // skip if the constructor is run in core code
    // some fake widgets are still instantiated to prevent breaking imports
    if (consolePrefix()) {
      warnWidgetsDecommissioned();
    }
  }
}

function dummyCreateWidgetFrom() {
  return DummyWidget;
}

export {
  warnWidgetsDecommissioned,
  warnWidgetsDecommissioned as warnWidgetsDeprecation,
  warnWidgetsDecommissioned as queryRegistry,
  warnWidgetsDecommissioned as deleteFromRegistry,
  warnWidgetsDecommissioned as decorateWidget,
  warnWidgetsDecommissioned as traverseCustomWidgets,
  warnWidgetsDecommissioned as applyDecorators,
  warnWidgetsDecommissioned as resetDecorators,
  warnWidgetsDecommissioned as changeSetting,
  dummyCreateWidgetFrom as createWidgetFrom,
  dummyCreateWidgetFrom as createWidget,
  warnWidgetsDecommissioned as reopenWidget,
  DummyWidget,
  DummyWidget as default,
};
