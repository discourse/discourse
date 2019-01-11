import { propertyEqual, setting } from "discourse/lib/computed";

export default Ember.Mixin.create({
  isCurrentUser: propertyEqual("model.id", "currentUser.id"),
  showEmailOnProfile: setting("show_email_on_profile"),
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
