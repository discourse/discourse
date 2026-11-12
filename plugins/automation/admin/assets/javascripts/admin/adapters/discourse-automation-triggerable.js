import DiscourseAutomationAdapter from "./discourse-automation-adapter.js";

export default class TriggerableAdapter extends DiscourseAutomationAdapter {
  jsonMode = true;

  apiNameFor() {
    return "triggerable";
  }
}
