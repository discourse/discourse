import deprecated from "discourse/lib/deprecated";

const DECOMMISSION_URL = "https://meta.discourse.org/t/375332/1";

function decommissioned(fnName) {
  deprecated(
    `\`${fnName}\` has been decommissioned. Your site may not work properly. See ${DECOMMISSION_URL}`
  );
}

export function queryRegistry() {
  decommissioned("queryRegistry");
}

export function deleteFromRegistry() {
  decommissioned("deleteFromRegistry");
}

export function decorateWidget() {
  decommissioned("decorateWidget");
}

export function traverseCustomWidgets() {
  decommissioned("traverseCustomWidgets");
}

export function applyDecorators() {
  decommissioned("applyDecorators");
}

export function changeSetting() {
  decommissioned("changeSetting");
}

export function createWidgetFrom() {
  decommissioned("createWidgetFrom");
}

export function createWidget() {
  decommissioned("createWidget");
}

export function reopenWidget() {
  decommissioned("reopenWidget");
}
