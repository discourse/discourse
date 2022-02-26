import DiscourseAutomationAdapter from "./discourse-automation-adapter";

export default DiscourseAutomationAdapter.extend({
  apiNameFor() {
    return "automation";
  },

  jsonMode: true,
});
