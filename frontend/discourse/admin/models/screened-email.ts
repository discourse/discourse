import EmberObject, { computed } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export type ScreeningAction = "block" | "do_nothing" | "allow_admin";

/** `/admin/logs/screened_emails` record; `ip_address` is sent only to viewers who may see IPs. */
export interface ScreenedEmailFields {
  id: number;
  email: string;
  action: ScreeningAction;
  match_count: number;
  last_match_at: string | null;
  created_at: string;
  ip_address?: string | null;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface ScreenedEmail extends ScreenedEmailFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class ScreenedEmail extends EmberObject {
  static findAll(): Promise<ScreenedEmail[]> {
    return ajax("/admin/logs/screened_emails.json").then(function (
      screened_emails: ScreenedEmailFields[]
    ) {
      return screened_emails.map(function (b) {
        return ScreenedEmail.create(b);
      });
    });
  }

  @computed("action")
  get actionName(): string {
    return i18n("admin.logs.screened_actions." + this.action);
  }

  clearBlock(): Promise<{ success: string }> {
    return ajax("/admin/logs/screened_emails/" + this.id, {
      type: "DELETE",
    });
  }
}
