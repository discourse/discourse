import { withPluginApi } from "discourse/lib/plugin-api";

function initializeDiscourseAutomation() {}

export default {
  name: "discourse-automation",

  initialize() {
    withPluginApi("0.8.24", initializeDiscourseAutomation);
  }
};
