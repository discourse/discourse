export const NODE_DIRECT_SETTING_KEY_ATTRIBUTES = Object.freeze({
  notes: "notes",
  notesInFlow: "notes_in_flow",
  alwaysOutputData: "always_output_data",
  onError: "on_error",
  continueOnFail: "continue_on_fail",
});
export const NODE_DIRECT_SETTING_KEYS = Object.freeze(
  Object.keys(NODE_DIRECT_SETTING_KEY_ATTRIBUTES)
);
const CONTINUE_ON_ERROR_MODES = [
  "continueRegularOutput",
  "continueErrorOutput",
];

export function continuesOnError(configuration) {
  if (configuration?.onError) {
    return CONTINUE_ON_ERROR_MODES.includes(configuration.onError);
  }
  return configuration?.continueOnFail === true;
}

// Leaves an unchanged mode alone so an error output configured outside the editor survives.
export function withContinueOnError(configuration, enabled) {
  if (enabled === continuesOnError(configuration)) {
    return {};
  }

  return {
    onError: enabled ? "continueRegularOutput" : undefined,
    continueOnFail: undefined,
  };
}

export const FORM_TRIGGER_TYPE = "trigger:form";
export const FORM_TRIGGER_WEBHOOK_ID_KEY = "webhookId";

export function isFormTriggerNodeType(nodeType) {
  return nodeType === FORM_TRIGGER_TYPE;
}
