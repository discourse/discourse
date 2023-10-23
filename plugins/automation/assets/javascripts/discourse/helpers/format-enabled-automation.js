import { iconHTML } from "discourse-common/lib/icon-library";
import { htmlSafe } from "@ember/template";

export default function formatEnabledAutomation(enabled, trigger) {
  if (enabled && trigger.id) {
    return htmlSafe(
      iconHTML("check", {
        class: "enabled-automation",
        title: "discourse_automation.models.automation.enabled.label",
      })
    );
  } else {
    return htmlSafe(
      iconHTML("times", {
        class: "disabled-automation",
        title: "discourse_automation.models.automation.disabled.label",
      })
    );
  }
}
