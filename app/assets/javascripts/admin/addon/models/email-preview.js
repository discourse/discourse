import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default class EmailPreview extends EmberObject {
  static findDigest(username, lastSeenAt) {
    return ajax("/admin/email/preview-digest.json", {
      data: { last_seen_at: lastSeenAt || oneWeekAgo(), username },
    }).then((result) => EmailPreview.create(result));
  }

  static sendDigest(username, lastSeenAt, email) {
    return ajax("/admin/email/send-digest.json", {
      type: "POST",
      data: { last_seen_at: lastSeenAt || oneWeekAgo(), username, email },
    });
  }
}

export function oneWeekAgo() {
  return moment().locale("en").subtract(7, "days").format("YYYY-MM-DD");
}
