import { iconHTML } from "discourse-common/lib/icon-library";
import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("format-enabled-automation", function (enabled, trigger) {
  if (enabled && trigger.id) {
    return iconHTML("check", {
      class: "enabled-automation",
      title: "discourse_automation.models.automation.enabled.label",
    }).htmlSafe();
  } else {
    return iconHTML("times", {
      class: "disabled-automation",
      title: "discourse_automation.models.automation.disabled.label",
    }).htmlSafe();
  }
});
