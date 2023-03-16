import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";

class EmailPreview extends EmberObject {}

export function oneWeekAgo() {
  return moment().locale("en").subtract(7, "days").format("YYYY-MM-DD");
}

EmailPreview.reopenClass({
  findDigest(username, lastSeenAt) {
    return ajax("/admin/email/preview-digest.json", {
      data: { last_seen_at: lastSeenAt || oneWeekAgo(), username },
    }).then((result) => EmailPreview.create(result));
  },

  sendDigest(username, lastSeenAt, email) {
    return ajax("/admin/email/send-digest.json", {
      type: "POST",
      data: { last_seen_at: lastSeenAt || oneWeekAgo(), username, email },
    });
  },
});

export default EmailPreview;
