import DiscourseAutomationAdapter from "./discourse-automation-adapter.js";

export default class AutomationAdapter extends DiscourseAutomationAdapter {
  jsonMode = true;

  apiNameFor() {
    return "automation";
  }
}
