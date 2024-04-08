import DiscourseAutomationAdapter from "./discourse-automation-adapter";

export default class TriggerableAdapter extends DiscourseAutomationAdapter {
  jsonMode = true;

  apiNameFor() {
    return "triggerable";
  }
}
