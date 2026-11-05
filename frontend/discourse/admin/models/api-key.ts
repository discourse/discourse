import { computed } from "@ember/object";
import type RestAdapter from "discourse/adapters/rest";
import AdminUser, {
  type BasicAdminUser,
} from "discourse/admin/models/admin-user";
import { ajax } from "discourse/lib/ajax";
import RestModel, {
  type RestModelClass,
  type RestModelStoreAttrs,
  type RestPayload,
} from "discourse/models/rest";

/** Scopes serialized on detail/create/update responses, absent from index rows. */
export interface ApiKeyScope {
  resource: string;
  action: string;
  parameters: string[];
  urls: string[];
  allowed_parameters: Record<string, string[]> | null;
  key: string;
}

/** Scope catalogue selections are request data, separate from serialized key scopes. */
export type ApiKeyScopeSelection = {
  scope_id: string;
  key: string;
  name: string;
  params: string[] | null;
  urls?: string[];
} & Record<string, string | string[] | boolean | null | undefined>;

/** Index fields plus conditional detail fields and mutable creation inputs. */
export interface ApiKeyFields {
  id: number;
  truncated_key: string;
  description: string | null;
  scope_mode: "global" | "read_only" | "granular" | null;
  last_used_at: string | null;
  revoked_at: string | null;
  created_at?: string;
  updated_at?: string;
  key?: string;
  api_key_scopes?: ApiKeyScope[];
  username?: string | null;
  scopes?: (ApiKeyScopeSelection | undefined)[] | null;
  _user?: AdminUser | null;
  _created_by?: AdminUser | null;
}

/** Setters accept basic wire users, while getters expose wrapped instances. */
export type ApiKeyCreateAttrs<M = ApiKey> = Partial<
  Omit<M, "user" | "created_by">
> &
  RestModelStoreAttrs &
  RestPayload & {
    user?: BasicAdminUser | AdminUser | null;
    created_by?: BasicAdminUser | AdminUser | null;
  };

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface ApiKey extends ApiKeyFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class ApiKey extends RestModel {
  declare static create: <C extends RestModelClass>(
    this: C,
    attrs?: ApiKeyCreateAttrs<InstanceType<C>>
  ) => InstanceType<C>;

  @computed("_user")
  get user(): AdminUser | null | undefined {
    return this._user;
  }

  set user(value: BasicAdminUser | AdminUser | null | undefined) {
    if (value && !(value instanceof AdminUser)) {
      this.set("_user", AdminUser.create(value));
    } else {
      this.set("_user", value);
    }
  }

  @computed("truncated_key")
  get truncatedKey() {
    return `${this.truncated_key} ...`;
  }

  @computed("_created_by")
  get createdBy(): AdminUser | null | undefined {
    return this._created_by;
  }

  @computed("description")
  get shortDescription(): string | null {
    if (!this.description || this.description.length < 40) {
      return this.description;
    }
    return `${this.description.substring(0, 40)}...`;
  }

  @computed()
  get basePath(): string {
    // TODO(typescript-pending): StoreAdapter omits pathFor; remove when its REST adapter surface is typed.
    return (
      this.store.adapterFor("api-key") as ReturnType<
        typeof this.store.adapterFor
      > &
        Pick<RestAdapter, "pathFor">
    ).pathFor(this.store, "api-key", this.id);
  }

  /** Write-only raw input; read the wrapped user through createdBy. */
  set created_by(value: BasicAdminUser | AdminUser | null | undefined) {
    if (value && !(value instanceof AdminUser)) {
      this.set("_created_by", AdminUser.create(value));
    } else {
      this.set("_created_by", value);
    }
  }

  revoke() {
    return ajax(`${this.basePath}/revoke`, {
      type: "POST",
    }).then((result: { api_key: ApiKeyCreateAttrs }) =>
      this.setProperties(result.api_key)
    );
  }

  undoRevoke() {
    return ajax(`${this.basePath}/undo-revoke`, {
      type: "POST",
    }).then((result: { api_key: ApiKeyCreateAttrs }) =>
      this.setProperties(result.api_key)
    );
  }

  createProperties(): Pick<
    ApiKey,
    "description" | "username" | "scopes" | "scope_mode"
  > {
    return this.getProperties(
      "description",
      "username",
      "scopes",
      "scope_mode"
    );
  }
}

declare module "discourse/services/store" {
  interface ModelRegistry {
    "api-key": ApiKey;
  }
  interface ModelCreateAttrsRegistry {
    "api-key": ApiKeyCreateAttrs;
  }
}
