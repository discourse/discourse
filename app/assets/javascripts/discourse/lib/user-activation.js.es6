import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { userPath } from "discourse/lib/url";

export function resendActivationEmail(username) {
  return ajax(userPath("action/send_activation_email"), {
    type: "POST",
    data: { username }
  }).catch(popupAjaxError);
}

export function changeEmail(data) {
  return ajax(userPath("update-activation-email"), { data, type: "PUT" });
}
