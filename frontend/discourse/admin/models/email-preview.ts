import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";

/** `/admin/email/preview` response. */
export interface EmailPreviewFields {
  subject: string | null;
  html_content: string;
  text_content: string;
}

/** Message types, editable templates, and custom themes available to administrators. */
export interface EmailPreviewCatalog {
  message_types: { id: string; title: string }[];
  email_templates: { id: string; title: string }[];
  branding_themes: { id: number; title: string }[];
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface EmailPreview extends EmailPreviewFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class EmailPreview extends EmberObject {
  static findTypes(): Promise<EmailPreviewCatalog> {
    return ajax("/admin/email/preview-types.json");
  }

  static findPreview(
    username: string | null | undefined,
    lastSeenAt?: string | null,
    emailType?: string | null,
    locale?: string | null,
    themeId?: number | string | null
  ): Promise<EmailPreview> {
    return ajax("/admin/email/preview.json", {
      data: {
        last_seen_at: lastSeenAt || oneWeekAgo(),
        username,
        email_type: emailType,
        locale,
        theme_id: themeId,
      },
    }).then((result: EmailPreviewFields) => EmailPreview.create(result));
  }

  static sendPreview(
    username: string | null | undefined,
    lastSeenAt: string | null | undefined,
    email: string | null | undefined,
    emailType?: string | null,
    locale?: string | null,
    themeId?: number | string | null
  ): Promise<{ success?: string; errors?: string | string[] | null }> {
    return ajax("/admin/email/send-preview.json", {
      type: "POST",
      data: {
        last_seen_at: lastSeenAt || oneWeekAgo(),
        username,
        email,
        email_type: emailType,
        locale,
        theme_id: themeId,
      },
    });
  }
}

export function oneWeekAgo(): string {
  return moment().locale("en").subtract(7, "days").format("YYYY-MM-DD");
}

/** The application provides moment globally. */
declare const moment: typeof import("moment");
