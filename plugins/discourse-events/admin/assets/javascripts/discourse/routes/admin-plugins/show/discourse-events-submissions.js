import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { listRegistrationForms } from "discourse/plugins/discourse-events/discourse/lib/registration-forms";

export default class EventSubmissionsRoute extends DiscourseRoute {
  queryParams = {
    page: { refreshModel: true },
    formId: { refreshModel: true },
    search: { refreshModel: true, replace: true },
  };

  async model({ page, formId, search }) {
    const data = { page };
    if (formId) {
      data.form_id = formId;
    }
    if (search) {
      data.search = search;
    }
    const [submissions, forms] = await Promise.all([
      ajax("/admin/plugins/discourse-events/submissions.json", { data }),
      this.forms ?? listRegistrationForms({ forReports: true }),
    ]);
    this.forms = forms;
    return { ...submissions, forms };
  }

  @action
  registrationFormDeleted() {
    this.forms = null;
    this.controller.filterByForm("all");
  }

  resetController(controller, isExiting) {
    if (isExiting) {
      this.forms = null;
      controller.formId = null;
      controller.clearSearch();
    }
  }
}
