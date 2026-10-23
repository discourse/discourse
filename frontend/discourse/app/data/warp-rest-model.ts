import { dependentKeyCompat } from "@ember/object/compat";
import type { HTTPMethod } from "@warp-drive/core/types/request";
import type { LegacyResourceSchema } from "@warp-drive/core/types/schema/fields";
import type {
  CollectionResourceDocument,
  JsonApiDocument,
  SingleResourceDocument,
} from "@warp-drive/core/types/spec/json-api-raw";
import {
  exposeExtraAttributes,
  extraAttributesFor,
} from "discourse/data/extra-attributes";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import type WarpStoreService from "discourse/services/warp-store";

export function warpStore(): WarpStoreService {
  return getOwnerWithFallback().lookup("service:warp-store");
}

/**
 * The record a wrapper reads its fields from: a cached LegacyMode record, or a
 * draft attrs bag before the first save.
 */
export type WarpResource = Record<string, unknown>;

/** Turns rooted server JSON into a JSON:API document for the cache. */
export type Normalizer = (payload: unknown) => JsonApiDocument;

/**
 * A request object for `warpStore().request`, built by the modules in
 * `discourse/data/builders`. RPC-style requests carry no `op`.
 */
export interface WarpRequest {
  url: string;
  method: HTTPMethod;
  op?: string;
  data?: { type: string; id: string };
  options?: { body?: unknown; normalize?: Normalizer };
}

export interface WarpRestBuilders {
  list?: (opts?: Record<string, unknown>) => WarpRequest;
  one?: (id: string | number) => WarpRequest;
  save?: (record: WarpRestModel, data?: Record<string, unknown>) => WarpRequest;
  delete?: (id: string | number) => WarpRequest;
}

type WarpRestModelClass<T extends WarpRestModel> = (new (
  resource?: WarpResource | null
) => T) &
  Pick<typeof WarpRestModel, "type" | "normalize" | "builders">;

// Pure WarpDrive base. Ember/RestModel-API shims live in `rest-compat.ts`.
//
// Subclass contract:
//   static type             — schema type, e.g. "badge"
//   static normalize        — rooted JSON → JSON:API document
//   static builders         — { list(opts), one(id), save(record, data), delete(id) }
export default class WarpRestModel {
  static type: string | null = null;

  static normalize: Normalizer | null = null;

  static builders: WarpRestBuilders | null = null;

  static findAll<T extends WarpRestModel>(
    this: WarpRestModelClass<T>,
    opts?: Record<string, unknown>
  ): Promise<T[]> {
    return requestMany(this, this.builders!.list!(opts));
  }

  static findById<T extends WarpRestModel>(
    this: WarpRestModelClass<T>,
    id: string | number
  ): Promise<T> {
    return requestOne(this, this.builders!.one!(id));
  }

  // Synchronous ingest for preloaded payloads (PreloadStore, embedded sub-payloads).
  static createFromJson<T extends WarpRestModel>(
    this: WarpRestModelClass<T>,
    json: unknown
  ): T | T[] {
    const store = warpStore();
    const document = this.normalize!(json);

    if (Array.isArray(document.data)) {
      const records = store.push(
        document as CollectionResourceDocument
      ) as WarpResource[];
      return attachMeta(
        records.map((r) => new this(r)),
        document.meta
      );
    }
    // An empty document pushes as `null`.
    return new this(
      store.push(document as SingleResourceDocument) as WarpResource | null
    );
  }

  // Schema fields are installed as prototype forwarders by
  // `defineFieldForwarders`, so they can't be declared here.
  [field: string]: unknown;

  #resource: WarpResource | null | undefined;

  constructor(resource?: WarpResource | null) {
    this.#resource = resource;
    this._applyExtraAttributes(resource?.id);
  }

  get __resource(): WarpResource | null | undefined {
    return this.#resource;
  }

  // The resource this wrapper was constructed with, bypassing any subclass
  // `__resource` override. Base constructors must use this: a subclass's own
  // fields (and the getter that reads them) aren't initialized during `super()`.
  get __ownResource(): WarpResource | null | undefined {
    return this.#resource;
  }

  updateFromJson(json: unknown): this {
    if (json == null) {
      return this;
    }
    const Klass = this.constructor as typeof WarpRestModel;
    const document = Klass.normalize!(json);
    if (!document || Array.isArray(document.data)) {
      return this;
    }
    warpStore().push(document as SingleResourceDocument);
    this._adoptResource(document.data?.id);
    return this;
  }

  async save(data?: Record<string, unknown>): Promise<unknown> {
    const Klass = this.constructor as typeof WarpRestModel;
    const store = warpStore();
    const result = await store.request<{ data?: WarpResource | null }>(
      Klass.builders!.save!(this, data)
    );
    this._adoptResource(result.content?.data?.id);
    return this;
  }

  async destroy(): Promise<void> {
    const Klass = this.constructor as typeof WarpRestModel;
    const id = this.id as string | number | null | undefined;
    if (id == null) {
      return;
    }
    await warpStore().request(Klass.builders!.delete!(id));
  }

  // Attributes the schema doesn't declare never reach the cache; re-attach the
  // ones normalization retained for this identity. Called on construction and
  // whenever the wrapper adopts a cached record — subclasses with their own
  // ingest path (`TopicDetails`) call it after pushing.
  _applyExtraAttributes(id: unknown): void {
    const { type } = this.constructor as typeof WarpRestModel;
    if (type == null || id == null) {
      return;
    }

    const extras = extraAttributesFor(type, String(id));
    if (extras) {
      exposeExtraAttributes(this, extras);
    }
  }

  // Swap `__resource` to the cached record for `id`.
  _adoptResource(id: unknown): void {
    if (id == null) {
      return;
    }
    const Klass = this.constructor as typeof WarpRestModel;
    const cached = warpStore().peekRecord({
      type: Klass.type!,
      id: String(id),
    }) as WarpResource | null;
    if (cached && cached !== this.#resource) {
      this.#resource = cached;
    }
    this._applyExtraAttributes(id);
  }
}

// Attach document-level `meta` keys to the returned array so legacy callers
// can read `result.grant_count` / `result.username` directly.
export function attachMeta<T extends unknown[]>(
  records: T,
  meta: object | undefined
): T {
  if (meta) {
    Object.assign(records, meta);
  }
  return records;
}

export async function requestMany<T>(
  Klass: new (resource?: WarpResource | null) => T,
  request: WarpRequest
): Promise<T[]> {
  const { content } = await warpStore().request<{
    data?: WarpResource[];
    meta?: object;
  }>(request);
  return attachMeta(
    (content?.data ?? []).map((r) => new Klass(r)),
    content?.meta
  );
}

export async function requestOne<T>(
  Klass: new (resource?: WarpResource | null) => T,
  request: WarpRequest
): Promise<T> {
  const { content } = await warpStore().request<{ data?: WarpResource }>(
    request
  );
  return new Klass(content?.data);
}

// Install prototype getters/setters reading/writing `__resource` for each
// schema field. Subclass-defined getters (image, url, ...) take precedence —
// they're already on the prototype when this runs.
export function defineFieldForwarders(
  Klass: typeof WarpRestModel,
  schema: LegacyResourceSchema
): void {
  const proto = Klass.prototype;
  const fieldKinds = new Map<string, string>();
  if (schema.identity?.name) {
    fieldKinds.set(schema.identity.name, "@id");
  }
  for (const field of schema.fields ?? []) {
    if (field.name && !fieldKinds.has(field.name)) {
      fieldKinds.set(field.name, field.kind);
    }
  }
  for (const [name, kind] of fieldKinds) {
    // Skip names that resolve anywhere on the prototype chain — this is what
    // keeps subclass getters and base methods (save, get, set, ...) from
    // being shadowed by legacy-derived schema fields of the same name.
    if (name in proto) {
      continue;
    }
    const descriptor: PropertyDescriptor & ThisType<WarpRestModel> = {
      configurable: true,
      get() {
        return this.__resource?.[name];
      },
    };
    // JSON:API stores ids as strings; coerce numeric ones back so
    // `badge.id === 1126` still works at Discourse call sites.
    if (kind === "@id") {
      descriptor.get = function (this: WarpRestModel) {
        const raw = this.__resource?.[name];
        if (typeof raw !== "string") {
          return raw;
        }
        const num = Number(raw);
        return Number.isFinite(num) && String(num) === raw ? num : raw;
      };
    }
    // Relationships are read-only through the wrapper.
    if (kind === "attribute") {
      descriptor.set = function (this: WarpRestModel, value: unknown) {
        if (this.__resource) {
          this.__resource[name] = value;
        }
      };
    }
    // Classic computed consumers observe the wrapper, not the cached record.
    Object.defineProperty(
      proto,
      name,
      dependentKeyCompat(proto, name, descriptor)
    );
  }
}
