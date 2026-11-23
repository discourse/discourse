import { dependentKeyCompat } from "@ember/object/compat";
import type { LegacyResourceSchema } from "@warp-drive/core/types/schema/fields";
import type {
  CollectionResourceDocument,
  JsonApiDocument,
} from "@warp-drive/core/types/spec/json-api-raw";
import {
  exposeExtraAttributes,
  extraAttributesFor,
} from "discourse/data/extra-attributes";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import type { RestPayload } from "discourse/models/rest";
import type WarpStore from "discourse/services/warp-store";

/** The application's WarpDrive store service. */
export function warpStore(): WarpStore {
  return getOwnerWithFallback().lookup("service:warp-store");
}

/** JSON:API ids are strings; the `@id` forwarder hands numeric ones back as numbers. */
export type WarpResourceId = string | number;

/** Cached records and draft attribute bags share the wrapper's field access API. */
export type WarpResource = RestPayload & { id?: WarpResourceId | null };

/** Constructor arguments differ for wrappers that resolve their own resource. */
export type WarpRestModelClass = abstract new (
  ...args: never[]
) => WarpRestModel<unknown>;

/** Subclasses can declare a singleRecordRoot matching their normalizer's single-record envelope. */
type IngestResult<C extends WarpRestModelClass, P> = C extends {
  singleRecordRoot: infer Root extends string;
}
  ? P extends null | undefined
    ? InstanceType<C>
    : Root extends keyof P
      ? P[Root] extends object
        ? InstanceType<C>
        : [P[Root]] extends [null | undefined]
          ? InstanceType<C>[]
          : InstanceType<C> | InstanceType<C>[]
      : InstanceType<C>[]
  : InstanceType<C> | InstanceType<C>[];

/** A request object built by the helpers in `discourse/data/builders/helpers`. */
export interface WarpRequest {
  url: string;

  /** The HTTP method, e.g. `"GET"` or `"PUT"`. */
  method: string;

  /** The cache operation the response applies as, e.g. `"query"` or `"updateRecord"`. */
  op: string;

  /** The record an update or delete targets, so the cache can find it. */
  data?: { type: string; id: string };

  options?: {
    /** The request payload, sent as JSON. */
    body?: unknown;

    /** Converts the rooted response payload into a JSON:API document for the cache. */
    normalize?: (payload: RestPayload | null | undefined) => JsonApiDocument;
  };
}

/** Request builders a subclass supplies for the base factories and instance methods. */
export interface WarpRestBuilders {
  /** Builds the request behind `findAll`. */
  list?: (opts?: RestPayload) => WarpRequest;

  /** Builds the request behind `findById`. */
  one?: (id: WarpResourceId) => WarpRequest;

  /** Builds the request behind `save`, from the record and the attributes to send. */
  save?: (record: WarpRestModel<unknown>, data: RestPayload) => WarpRequest;

  /** Builds the request behind `destroy`. */
  delete?: (id: WarpResourceId) => WarpRequest;
}

/**
 * Pure WarpDrive base. Ember/RestModel-API shims live in `rest-compat.ts`.
 * Subclasses set `type`, `normalize` and `builders`.
 *
 * @typeParam SaveResult - Additional results returned by a subclass's save implementation.
 */
// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class WarpRestModel<SaveResult = never> {
  /** The schema type, e.g. `"badge"`. */
  static type: string | null = null;

  /** Converts rooted JSON into a JSON:API document. */
  static normalize:
    | ((payload: RestPayload | null | undefined) => JsonApiDocument)
    | null = null;

  static builders: WarpRestBuilders | null = null;

  /** Fetches a list through `builders.list`; document `meta` keys are copied onto the array. */
  static findAll<C extends WarpRestModelClass>(
    this: C,
    opts?: RestPayload
  ): Promise<InstanceType<C>[] & RestPayload>;

  static findAll(opts?: RestPayload) {
    return requestMany(this, this.builders!.list!(opts));
  }

  /** Fetches one record through `builders.one`. */
  static findById<C extends WarpRestModelClass>(
    this: C,
    id: WarpResourceId
  ): Promise<InstanceType<C>>;

  static findById(id: WarpResourceId) {
    return requestOne(this, this.builders!.one!(id));
  }

  /**
   * Synchronous ingest for preloaded payloads (PreloadStore, embedded sub-payloads).
   * Returns a list when the normalized document holds many records, and one wrapper otherwise.
   * Subclasses may declare static singleRecordRoot to narrow rooted payloads without emitting a field.
   */
  static createFromJson<
    C extends WarpRestModelClass,
    P extends object | null | undefined,
  >(this: C, json: P): IngestResult<C, P>;

  static createFromJson(json: RestPayload | null | undefined) {
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
    // The store overloads cannot express a single-or-null document union.
    return new this(
      (store.push as (document: JsonApiDocument) => WarpResource | null)(
        document
      )
    );
  }

  #resource: WarpResource | null | undefined;

  /** Wraps a cached record or a draft attribute bag. */
  constructor(resource?: WarpResource | null) {
    this.#resource = resource;
    this._applyExtraAttributes(resource?.id);
  }

  /** The record that field forwarders read and write. Subclasses may resolve it themselves. */
  get __resource() {
    return this.#resource;
  }

  /**
   * The resource this wrapper was constructed with, bypassing any subclass
   * `__resource` override. Base constructors must use this: a subclass's own
   * fields (and the getter that reads them) aren't initialized during `super()`.
   */
  get __ownResource() {
    return this.#resource;
  }

  /**
   * Pushes a single-record payload into the cache and adopts the cached record.
   * Subclasses with their own ingest path may return `undefined`.
   */
  updateFromJson(json: RestPayload | null | undefined): this | undefined {
    if (json == null) {
      return this;
    }
    const Klass = this.constructor as typeof WarpRestModel;
    const document = Klass.normalize!(json);
    if (!document || Array.isArray(document.data)) {
      return this;
    }
    // The store overloads do not accept the union left by the array guard.
    (warpStore().push as (document: JsonApiDocument) => unknown)(document);
    this._adoptResource(document.data?.id);
    return this;
  }

  /** Sends `data` through `builders.save` and adopts the cached record from the response. */
  async save(data: RestPayload): Promise<this | SaveResult> {
    const Klass = this.constructor as typeof WarpRestModel;
    const store = warpStore();
    // Builders preserve the legacy string method type; the request layer expects HTTP methods.
    const result = await store.request<{ data?: WarpResource | null }>(
      Klass.builders!.save!(this, data) as Parameters<WarpStore["request"]>[0]
    );
    this._adoptResource(result.content?.data?.id);
    return this;
  }

  /** Deletes the record through `builders.delete`; does nothing without an id. */
  async destroy() {
    const Klass = this.constructor as typeof WarpRestModel;
    const id = this.id;
    if (id == null) {
      return;
    }
    await warpStore().request(
      Klass.builders!.delete!(id) as Parameters<WarpStore["request"]>[0]
    );
  }

  /**
   * Attributes the schema doesn't declare never reach the cache; re-attach the
   * ones normalization retained for this identity. Called on construction and
   * whenever the wrapper adopts a cached record — subclasses with their own
   * ingest path (`TopicDetails`) call it after pushing.
   */
  _applyExtraAttributes(id: WarpResourceId | null | undefined) {
    const { type } = this.constructor as typeof WarpRestModel;
    if (type == null || id == null) {
      return;
    }

    const extras = extraAttributesFor(type, String(id));
    if (extras) {
      exposeExtraAttributes(this, extras);
    }
  }

  /** Swap `__resource` to the cached record for `id`. */
  _adoptResource(id: WarpResourceId | null | undefined) {
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

/**
 * Attach document-level `meta` keys to the returned array so legacy callers
 * can read `result.grant_count` / `result.username` directly.
 */
export function attachMeta<T>(
  records: T[],
  meta?: RestPayload
): T[] & RestPayload {
  if (meta) {
    Object.assign(records, meta);
  }
  return records as T[] & RestPayload;
}

/** Runs a list request and wraps each record in `Klass`, copying document `meta` onto the array. */
export function requestMany<C extends WarpRestModelClass>(
  Klass: C,
  request: WarpRequest
): Promise<InstanceType<C>[] & RestPayload>;
export async function requestMany(
  Klass: new (resource?: WarpResource | null) => WarpRestModel<unknown>,
  request: WarpRequest
) {
  const { content } = await warpStore().request<{
    data?: WarpResource[];
    meta?: RestPayload;
  }>(request as Parameters<WarpStore["request"]>[0]);
  return attachMeta(
    (content?.data ?? []).map((r) => new Klass(r)),
    content?.meta
  );
}

/** Runs a single-record request and wraps the result in `Klass`. */
export function requestOne<C extends WarpRestModelClass>(
  Klass: C,
  request: WarpRequest
): Promise<InstanceType<C>>;
export async function requestOne(
  Klass: new (resource?: WarpResource | null) => WarpRestModel<unknown>,
  request: WarpRequest
) {
  const { content } = await warpStore().request<{ data?: WarpResource | null }>(
    request as Parameters<WarpStore["request"]>[0]
  );
  return new Klass(content?.data);
}

/**
 * Install prototype getters/setters reading/writing `__resource` for each
 * schema field. Subclass-defined getters (image, url, ...) take precedence —
 * they're already on the prototype when this runs.
 */
export function defineFieldForwarders(
  Klass: WarpRestModelClass,
  schema: LegacyResourceSchema
) {
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
    const descriptor: TypedPropertyDescriptor<unknown> = {
      configurable: true,
      get(this: WarpRestModel<unknown>) {
        return this.__resource?.[name];
      },
    };
    // JSON:API stores ids as strings; coerce numeric ones back so
    // `badge.id === 1126` still works at Discourse call sites.
    if (kind === "@id") {
      descriptor.get = function (this: WarpRestModel<unknown>) {
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
      descriptor.set = function (this: WarpRestModel<unknown>, value: unknown) {
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

/** Declared only: schema forwarders install the accessor, and subclasses may supply a getter. */
// eslint-disable-next-line @typescript-eslint/no-unused-vars -- Declaration merging requires the class's type parameters.
export default interface WarpRestModel<SaveResult = never> {
  id?: WarpResourceId | null;
}
