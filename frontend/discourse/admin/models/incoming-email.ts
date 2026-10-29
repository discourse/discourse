import EmberObject from "@ember/object";
import AdminUser, {
  type BasicAdminUser,
} from "discourse/admin/models/admin-user";
import type { EmailLogFilter } from "discourse/admin/models/email-log";
import { ajax } from "discourse/lib/ajax";

/** List rows only; detail lookups return IncomingEmailDetails. */
export interface IncomingEmailFields {
  id?: number;
  created_at?: string;
  user: AdminUser | null;
  post_url?: string;
  from_address?: string | null;
  to_addresses: string[] | null;
  cc_addresses?: string[] | null;
  subject?: string | null;
  error?: string;
}

/** The factory mutates raw users into AdminUser instances. */
export type IncomingEmailCreateAttrs<M = IncomingEmail> = Partial<
  Omit<M, "user">
> & {
  user?: BasicAdminUser | AdminUser | null;
};

/** Rootless detail response, with no list identity or addresses. */
export interface IncomingEmailDetails {
  error?: string;
  error_description?: string;
  rejection_message: string | null;
  headers: string;
  subject: string;
  body: string;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface IncomingEmail extends IncomingEmailFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class IncomingEmail extends EmberObject {
  static create<C extends abstract new (...args: never[]) => EmberObject>(
    this: C,
    attrs?: IncomingEmailCreateAttrs<InstanceType<C>> | null
  ): InstanceType<C>;

  /** Keeps the inherited variadic factory assignable without advertising extra runtime arguments. */
  static create(this: never, ...args: unknown[]): never;
  static create(attrs?: IncomingEmailCreateAttrs | null) {
    attrs = attrs || {};

    if (attrs.user) {
      attrs.user = AdminUser.create(attrs.user);
    }

    return super.create(attrs);
  }

  static find(id: string | number): Promise<IncomingEmailDetails> {
    return ajax(`/admin/email-logs/incoming/${id}.json`);
  }

  static findByBounced(id: string | number): Promise<IncomingEmailDetails> {
    return ajax(`/admin/email-logs/incoming_from_bounced/${id}.json`);
  }

  static findAll(
    filter?: EmailLogFilter | null,
    offset?: number | null
  ): Promise<IncomingEmail[]> {
    filter = filter || {};
    offset = offset || 0;

    const status = filter.status || "received";
    delete filter.status;

    return ajax(`/admin/email-logs/${status}.json?offset=${offset}`, {
      data: filter,
    }).then((incomings: IncomingEmailCreateAttrs[]) =>
      incomings.map((incoming) => IncomingEmail.create(incoming))
    );
  }
}
