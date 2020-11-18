import DiscourseAutomationAdapter from "./discourse-automation-adapter";

export default DiscourseAutomationAdapter.extend({
  apiNameFor() {
    return "trigger";
  },

  jsonMode: true
});
