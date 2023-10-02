import DiscourseAutomationAdapter from "./discourse-automation-adapter";

export default class AutomationAdapter extends DiscourseAutomationAdapter {
  jsonMode = true;

  apiNameFor() {
    return "automation";
  }
}
