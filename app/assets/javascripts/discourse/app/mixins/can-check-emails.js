import { alias, and, or } from "@ember/object/computed";
import Mixin from "@ember/object/mixin";
import { propertyEqual, setting } from "discourse/lib/computed";

export default Mixin.create({
  isCurrentUser: propertyEqual("model.id", "currentUser.id"),
  showEmailOnProfile: setting("moderators_view_emails"),
  canStaffCheckEmails: and("showEmailOnProfile", "currentUser.staff"),
  canAdminCheckEmails: alias("currentUser.admin"),
  canCheckEmails: or(
    "isCurrentUser",
    "canStaffCheckEmails",
    "canAdminCheckEmails"
  ),
});
