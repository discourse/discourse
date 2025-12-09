import setupDeprecationWorkflow from "ember-cli-deprecation-workflow/addon";
import DeprecationWorkflow from "./deprecation-workflow";

setupDeprecationWorkflow({ workflow: DeprecationWorkflow.emberWorkflowList });
