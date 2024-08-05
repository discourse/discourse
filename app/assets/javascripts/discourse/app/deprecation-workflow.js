import setupDeprecationWorkflow from "ember-cli-deprecation-workflow";
import DEPRECATION_WORKFLOW from "discourse-common/deprecation-workflow";

// We're using RAISE_ON_DEPRECATION in environment.js instead of
// `throwOnUnhandled` here since it is easier to toggle.
setupDeprecationWorkflow({ workflow: DEPRECATION_WORKFLOW });
