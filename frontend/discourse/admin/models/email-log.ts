import EmberObject from "@ember/object";
import AdminUser, {
  type BasicAdminUser,
} from "discourse/admin/models/admin-user";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";

/** Common, sent/bounced and skipped serializer fields; variant fields are optional. */
export interface EmailLogFields {
  id?: number;
  created_at?: string;
  user: AdminUser | null;
  post_url?: string;
  to_address?: string;
  email_type?: string;
  user_id: number | null;
  post_description?: string;
  cc_addresses?: string[] | null;
  post_id?: number | null;
  reply_key?: string;
  bounced?: boolean;
  has_bounce_key?: boolean;
  smtp_transaction_response?: string | null;
  skipped_reason?: string;
}

/** The factory mutates raw users into AdminUser instances. */
export type EmailLogCreateAttrs<M = EmailLog> = Partial<Omit<M, "user">> & {
  user?: BasicAdminUser | AdminUser | null;
};

/** findAll consumes status by deleting it from this object. */
export interface EmailLogFilter {
  status?: string;
  address?: string;
  user?: string;
  type?: string;
  [key: string]: string | number | boolean | null | undefined;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface EmailLog extends EmailLogFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class EmailLog extends EmberObject {
  static create<C extends abstract new (...args: never[]) => EmberObject>(
    this: C,
    attrs?: EmailLogCreateAttrs<InstanceType<C>> | null
  ): InstanceType<C>;

  /** Keeps the inherited variadic factory assignable without advertising extra runtime arguments. */
  static create(this: never, ...args: unknown[]): never;
  static create(attrs?: EmailLogCreateAttrs | null) {
    attrs = attrs || {};

    if (attrs.user) {
      attrs.user = AdminUser.create(attrs.user);
    }

    if (attrs.post_url) {
      attrs.post_url = getURL(attrs.post_url);
    }

    return super.create(attrs);
  }

  static findAll(
    filter?: EmailLogFilter | null,
    offset?: number | null
  ): Promise<EmailLog[]> {
    filter = filter || {};
    offset = offset || 0;

    const status = filter.status || "sent";
    delete filter.status;

    return ajax(`/admin/email-logs/${status}.json?offset=${offset}`, {
      data: filter,
    }).then((logs: EmailLogCreateAttrs[]) =>
      logs.map((log) => EmailLog.create(log))
    );
  }
}

declare module "discourse/services/store" {
  interface ModelRegistry {
    "email-log": EmailLog;
  }
  interface ModelCreateAttrsRegistry {
    "email-log": EmailLogCreateAttrs;
  }
}
