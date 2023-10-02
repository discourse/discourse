import DiscourseAutomationAdapter from "./discourse-automation-adapter";

export default class ScriptableAdapter extends DiscourseAutomationAdapter {
  jsonMode = true;

  apiNameFor() {
    return "scriptable";
  }
}
