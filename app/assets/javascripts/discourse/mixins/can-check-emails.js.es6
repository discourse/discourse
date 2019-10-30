import { propertyEqual, setting } from "discourse/lib/computed";
import Mixin from "@ember/object/mixin";

export default Mixin.create({
  isCurrentUser: propertyEqual("model.id", "currentUser.id"),
  showEmailOnProfile: setting("moderators_view_emails"),
  canStaffCheckEmails: Ember.computed.and(
    "showEmailOnProfile",
    "currentUser.staff"
  ),
  canAdminCheckEmails: Ember.computed.alias("currentUser.admin"),
  canCheckEmails: Ember.computed.or(
    "isCurrentUser",
    "canStaffCheckEmails",
    "canAdminCheckEmails"
  )
});
