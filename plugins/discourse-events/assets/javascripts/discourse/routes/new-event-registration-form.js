import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import {
  canCreateRegistrationForm,
  newRegistrationForm,
} from "../lib/registration-forms.js";

export default class NewEventRegistrationFormRoute extends DiscourseRoute {
  @service router;
  @service siteSettings;

  beforeModel() {
    if (!canCreateRegistrationForm(this.currentUser, this.siteSettings)) {
      return this.router.replaceWith("discovery.latest");
    }
  }

  model() {
    return newRegistrationForm();
  }

  titleToken() {
    return i18n("event_registration.library.new");
  }
}
