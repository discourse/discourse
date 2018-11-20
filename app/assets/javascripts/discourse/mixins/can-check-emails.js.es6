import { propertyEqual, setting } from "discourse/lib/computed";

export default Ember.Mixin.create({
  isCurrentUser: propertyEqual("model.id", "currentUser.id"),
  showEmailOnProfile: setting("show_email_on_profile"),
  canStaffCheckEmails: Em.computed.and(
    "showEmailOnProfile",
    "currentUser.staff"
  ),
  canAdminCheckEmails: Em.computed.alias("currentUser.admin"),
  canCheckEmails: Em.computed.or(
    "isCurrentUser",
    "canStaffCheckEmails",
    "canAdminCheckEmails"
  )
});
