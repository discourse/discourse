export default Ember.Mixin.create({
  isOwnEmail: Discourse.computed.propertyEqual("model.id", "currentUser.id"),
  showEmailOnProfile: Discourse.computed.setting("show_email_on_profile"),
  canStaffCheckEmails: Em.computed.and("showEmailOnProfile", "currentUser.staff"),
  canAdminCheckEmails: Em.computed.alias("currentUser.admin"),
  canCheckEmails: Em.computed.or("isOwnEmail", "canStaffCheckEmails", "canAdminCheckEmails"),
});
