import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";

/** `/admin/email/server-settings`; each mail transport supplies its own setting values. */
export interface EmailSettingsFields {
  delivery_method: string;
  settings: { name: string; value: unknown }[];
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface EmailSettings extends EmailSettingsFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class EmailSettings extends EmberObject {
  static find(): Promise<EmailSettings> {
    return ajax("/admin/email/server-settings.json").then(function (
      settings: EmailSettingsFields
    ) {
      return EmailSettings.create(settings);
    });
  }
}
