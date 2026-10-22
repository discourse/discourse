import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default class EmailPreview extends EmberObject {
  static findTypes() {
    return ajax("/admin/email/preview-types.json");
  }

  static findDigest(username, lastSeenAt, emailType, locale) {
    return ajax("/admin/email/preview-digest.json", {
      data: {
        last_seen_at: lastSeenAt || oneWeekAgo(),
        username,
        email_type: emailType,
        locale,
      },
    }).then((result) => EmailPreview.create(result));
  }

  static sendDigest(username, lastSeenAt, email, emailType, locale) {
    return ajax("/admin/email/send-digest.json", {
      type: "POST",
      data: {
        last_seen_at: lastSeenAt || oneWeekAgo(),
        username,
        email,
        email_type: emailType,
        locale,
      },
    });
  }
}

export function oneWeekAgo() {
  return moment().locale("en").subtract(7, "days").format("YYYY-MM-DD");
}
