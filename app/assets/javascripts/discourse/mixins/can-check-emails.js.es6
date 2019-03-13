import { propertyEqual, setting } from "discourse/lib/computed";

export default Ember.Mixin.create({
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
