import { withPluginApi } from "discourse/lib/plugin-api";

function initializeDiscourseAutomation(api) {
  console.log("init", api);
  api.addStorePluralization("workflow-action", "workflow-actions");
}

export default {
  name: "discourse-automation",

  initialize() {
    withPluginApi("0.8.24", initializeDiscourseAutomation);
  }
};
