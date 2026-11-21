import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import { resettableTracked } from "discourse/lib/tracked-tools";
import { i18n } from "discourse-i18n";
import {
  ACCOUNT_ONLY,
  downloadRegistrationSubmissions,
} from "discourse/plugins/discourse-events/discourse/lib/registration-forms";

export default class EventSubmissionsController extends Controller {
  @service dialog;

  @tracked page = 1;
  @tracked formId = null;
  @tracked search = "";
  @resettableTracked searchInput = this.search;
  queryParams = ["page", { formId: "form_id" }, "search"];

  #searchTimer;

  get formOptions() {
    return [
      { value: "all", label: i18n("event_registration.submissions.all_forms") },
      { value: ACCOUNT_ONLY, label: i18n("event_registration.account_only") },
      ...this.model.forms.map(({ id, title }) => ({
        value: String(id),
        label: title,
      })),
    ];
  }

  get selectedForm() {
    return this.formId ? String(this.formId) : "all";
  }

  @action
  filterByForm(value) {
    this.#applySearch();
    this.formId = value === "all" ? null : value;
  }

  @action
  searchChanged(event) {
    this.searchInput = event.target.value;
    this.#searchTimer = discourseDebounce(this, this.#applySearch, INPUT_DELAY);
  }

  @action
  clearSearch() {
    this.searchInput = "";
    this.#applySearch();
  }

  @action
  async download(eventId, closeMenu) {
    await closeMenu();
    return downloadRegistrationSubmissions(eventId, this.dialog);
  }

  #applySearch() {
    cancel(this.#searchTimer);
    this.page = 1;
    this.search = this.searchInput.trim() ? this.searchInput : "";
  }
}
