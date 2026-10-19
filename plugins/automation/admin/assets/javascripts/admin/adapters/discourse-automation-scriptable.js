import DiscourseAutomationAdapter from "./discourse-automation-adapter.js";

export default class ScriptableAdapter extends DiscourseAutomationAdapter {
  jsonMode = true;

  apiNameFor() {
    return "scriptable";
  }
}
