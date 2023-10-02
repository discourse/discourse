import { iconHTML } from "discourse-common/lib/icon-library";
import { registerUnbound } from "discourse-common/lib/helpers";
import { htmlSafe } from "@ember/template";

registerUnbound("format-enabled-automation", function (enabled, trigger) {
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
});
