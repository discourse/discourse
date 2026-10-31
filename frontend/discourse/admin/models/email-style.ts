import RestModel from "discourse/models/rest";

/** `/admin/customize/email_style` record. */
export interface EmailStyleFields {
  id?: string;
  html?: string;
  css: string;
  default_html?: string;
  default_css: string;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface EmailStyle extends EmailStyleFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class EmailStyle extends RestModel {
  changed = false;

  setField(fieldName: "html" | "css", value: string): void {
    this.set(`${fieldName}`, value);
    this.set("changed", true);
  }
}

declare module "discourse/services/store" {
  interface ModelRegistry {
    "email-style": EmailStyle;
  }
}
