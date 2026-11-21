import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { exportEntity } from "discourse/lib/export-csv";
import { newQuestion } from "discourse/lib/form-definition";
import getURL from "discourse/lib/get-url";
import randomUUID from "discourse/lib/random-uuid";
import { i18n } from "discourse-i18n";

export const registrationFormsPath =
  "/admin/plugins/discourse-events/registration-forms";
export const ACCOUNT_ONLY = "account";

const endpoint = "/discourse-post-event/registration-forms";
const creationRequestParam = "eventFormRequest";

export function accountOnlyForm() {
  return { builtin: ACCOUNT_ONLY, fields: [] };
}

export function registrationFormSelection(id, definition) {
  if (definition?.builtin === ACCOUNT_ONLY) {
    return ACCOUNT_ONLY;
  }
  return id ?? (definition ? "legacy" : null);
}

export function registrationFormManagementUrl(currentUser) {
  return getURL(currentUser.admin ? registrationFormsPath : endpoint + "/mine");
}

function creationChannel(requestId) {
  return new BroadcastChannel(`event-registration-form:${requestId}`);
}

export function openRegistrationFormEditor(path, onCreated) {
  const requestId = randomUUID();
  const url = new URL(path, window.location.origin);
  url.searchParams.set(creationRequestParam, requestId);
  const tab = window.open(url.href, "_blank");
  if (!tab) {
    return;
  }

  tab.opener = null;
  const channel = creationChannel(requestId);
  channel.onmessage = ({ data }) => {
    channel.close();
    onCreated(data);
    tab.close();
  };
  return () => channel.close();
}

export function notifyRegistrationFormCreated(form) {
  const requestId = new URLSearchParams(window.location.search).get(
    creationRequestParam
  );
  if (requestId) {
    const channel = creationChannel(requestId);
    channel.postMessage({ id: form.id, title: form.definition.title });
    channel.close();
  }
}

export function canCreateRegistrationForm(currentUser, siteSettings) {
  return (
    currentUser?.admin ||
    Boolean(
      siteSettings.discourse_post_event_enabled &&
      currentUser?.can_create_discourse_post_event
    )
  );
}

export function newRegistrationForm() {
  return {
    definition: { title: "", description: "", fields: [newQuestion()] },
  };
}

export async function downloadRegistrationSubmissions(id, dialog) {
  try {
    await exportEntity("event_registrations", { id });
    dialog.alert(i18n("event_registration.export_queued"));
  } catch (error) {
    popupAjaxError(error);
  }
}

export async function listRegistrationForms({
  includeUsage,
  mine,
  forReports,
} = {}) {
  const { registration_forms } = await ajax(
    endpoint + (mine ? "/mine.json" : ".json"),
    {
      data: { include_usage: includeUsage, for_reports: forReports },
    }
  );
  return registration_forms;
}

export function fetchRegistrationForm(id, { edit = false } = {}) {
  return ajax(
    endpoint + "/" + encodeURIComponent(id) + (edit ? "/edit.json" : ".json")
  );
}

export function removeRegistrationForm(id) {
  return ajax(endpoint + "/" + encodeURIComponent(id) + ".json", {
    type: "DELETE",
  });
}

export function saveRegistrationForm(id, definition) {
  return ajax((id ? endpoint + "/" + id : endpoint) + ".json", {
    type: id ? "PUT" : "POST",
    contentType: "application/json",
    data: JSON.stringify({ definition }),
  });
}
