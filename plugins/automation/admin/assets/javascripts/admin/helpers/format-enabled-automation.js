import { htmlSafe } from "@ember/template";
import { iconHTML } from "discourse/lib/icon-library";

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
      iconHTML("xmark", {
        class: "disabled-automation",
        title: "discourse_automation.models.automation.disabled.label",
      })
    );
  }
}
