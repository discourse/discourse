import { getProperties } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

/** `/admin/email/templates` record; pluralized templates send a body per plural form. */
export interface EmailTemplateFields {
  id: string;
  title: string;
  subject: string | null;
  body: string | Record<string, string>;
  can_revert: boolean;
  interpolation_keys: string[];
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface EmailTemplate extends EmailTemplateFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class EmailTemplate extends RestModel {
  revert(): Promise<Pick<EmailTemplate, "subject" | "body" | "can_revert">> {
    return ajax(`/admin/email/templates/${this.id}`, {
      type: "DELETE",
    }).then((result: { email_template: EmailTemplateFields }) =>
      getProperties(result.email_template, "subject", "body", "can_revert")
    );
  }
}

declare module "discourse/services/store" {
  interface ModelRegistry {
    "email-template": EmailTemplate;
  }
}
