import DiscourseURL from "discourse/lib/url";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";

export function publishDoNotDisturbOnFor(user, duration) {
  return new Promise(function (resolve, reject) {
    ajax({
      url: "/do-not-disturb.json",
      type: "POST",
      data: { duration: duration },
    })
      .then((response) => {
        updateDoNotDisturbStatus(user, response.ends_at);
        return resolve();
      })
      .catch(reject);
  });
}

export function publishDoNotDisturbOffFor(user) {
  return new Promise(function (resolve, reject) {
    ajax({
      url: "/do-not-disturb.json",
      type: "DELETE",
    })
      .then(() => {
        updateDoNotDisturbStatus(user, null);
        return resolve();
      })
      .catch(reject);
  });
}
export function updateDoNotDisturbStatus(user, ends_at) {
  user.set("do_not_disturb_until", ends_at);
  DiscourseURL.appEvents.trigger(
    "do-not-disturb:changed",
    user.do_not_disturb_until
  );
}
