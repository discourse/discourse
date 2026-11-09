import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";

/** `/admin/email/preview-digest` response. */
export interface EmailPreviewFields {
  html_content: string;
  text_content: string;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface EmailPreview extends EmailPreviewFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class EmailPreview extends EmberObject {
  static findDigest(
    username: string | null | undefined,
    lastSeenAt?: string | null
  ): Promise<EmailPreview> {
    return ajax("/admin/email/preview-digest.json", {
      data: { last_seen_at: lastSeenAt || oneWeekAgo(), username },
    }).then((result: EmailPreviewFields) => EmailPreview.create(result));
  }

  static sendDigest(
    username: string | null | undefined,
    lastSeenAt: string | null | undefined,
    email: string | null | undefined
  ): Promise<{ success?: string; errors?: string | string[] | null }> {
    return ajax("/admin/email/send-digest.json", {
      type: "POST",
      data: { last_seen_at: lastSeenAt || oneWeekAgo(), username, email },
    });
  }
}

export function oneWeekAgo(): string {
  return moment().locale("en").subtract(7, "days").format("YYYY-MM-DD");
}

/** The application provides moment globally. */
declare const moment: typeof import("moment");
