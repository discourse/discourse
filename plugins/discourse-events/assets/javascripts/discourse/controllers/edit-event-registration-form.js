import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";

export default class EditEventRegistrationFormController extends Controller {
  @service router;

  @action
  returnToForms() {
    this.router.transitionTo("my-event-registration-forms");
  }
}
