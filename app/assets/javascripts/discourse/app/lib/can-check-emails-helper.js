import { getOwner, setOwner } from "@ember/owner";
import { service } from "@ember/service";
import User from "discourse/models/user";

export default class CanCheckEmailsHelper {
  @service siteSettings;
  @service currentUser;

  constructor(context) {
    setOwner(this, getOwner(context));
  }

  get canAdminCheckEmails() {
    return this.currentUser.admin;
  }

  get canCheckEmails() {
    const userId = this.model instanceof User ? this.model.id : null;
    const canStaffCheckEmails =
      this.siteSettings.moderators_view_emails && this.currentUser.staff;
    return (
      userId === this.currentUser.id ||
      this.canAdminCheckEmails ||
      canStaffCheckEmails
    );
  }
}
