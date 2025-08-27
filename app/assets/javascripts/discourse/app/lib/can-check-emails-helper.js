export default class CanCheckEmailsHelper {
  constructor(model_id, can_moderators_view_emails, currentUser) {
    this.model_id = model_id;
    this.can_moderators_view_emails = can_moderators_view_emails;
    this.currentUser = currentUser;
  }

  get canAdminCheckEmails() {
    return this.currentUser.admin;
  }

  get canCheckEmails() {
    // Anonymous users can't check emails
    if (!this.currentUser) {
      return false;
    }

    const canStaffCheckEmails =
      this.can_moderators_view_emails && this.currentUser.staff;
    return (
      this.model_id === this.currentUser.id ||
      this.canAdminCheckEmails ||
      canStaffCheckEmails
    );
  }
}
