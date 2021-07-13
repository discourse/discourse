import { and, readOnly } from "@ember/object/computed";
import Controller from "@ember/controller";

export default Controller.extend({
  canChangeCategoryPreferences: readOnly(
    "model.can_change_tracking_preferences"
  ),
  canChangeTagPreferences: and(
    "model.can_change_tracking_preferences",
    "siteSettings.tagging_enabled"
  ),
});
