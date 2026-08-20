import {
  exposeExtraAttributes,
  extraAttributesFor,
} from "discourse/data/extra-attributes";
import { getOwnerWithFallback } from "discourse/lib/get-owner";

export function warpStore() {
  return getOwnerWithFallback().lookup("service:warp-store");
}

// Pure WarpDrive base. Ember/RestModel-API shims live in `rest-compat.js`.
//
// Subclass contract:
//   static type             — schema type, e.g. "badge"
//   static normalize        — rooted JSON → JSON:API document
//   static builders         — { list(opts), one(id), save(record, data), delete(id) }
export default class WarpRestModel {
  static type = null;
  static normalize = null;
  static builders = null;

  static findAll(opts) {
    return requestMany(this, this.builders.list(opts));
  }

  static findById(id) {
    return requestOne(this, this.builders.one(id));
  }

  // Synchronous ingest for preloaded payloads (PreloadStore, embedded sub-payloads).
  static createFromJson(json) {
    const store = warpStore();
    const document = this.normalize(json);

    if (Array.isArray(document.data)) {
      const records = store.push(document);
      return attachMeta(
        records.map((r) => new this(r)),
        document.meta
      );
    }
    return new this(store.push(document));
  }

  #resource;

  constructor(resource) {
    this.#resource = resource;
    this._applyExtraAttributes(resource?.id);
  }

  get __resource() {
    return this.#resource;
  }

  // The resource this wrapper was constructed with, bypassing any subclass
  // `__resource` override. Base constructors must use this: a subclass's own
  // fields (and the getter that reads them) aren't initialized during `super()`.
  get __ownResource() {
    return this.#resource;
  }

  // Attributes the schema doesn't declare never reach the cache; re-attach the
  // ones normalization retained for this identity. Called on construction and
  // whenever the wrapper adopts a cached record — subclasses with their own
  // ingest path (`TopicDetails`) call it after pushing.
  _applyExtraAttributes(id) {
    const { type } = this.constructor;
    if (type == null || id == null) {
      return;
    }

    const extras = extraAttributesFor(type, String(id));
    if (extras) {
      exposeExtraAttributes(this, extras);
    }
  }

  // Swap `__resource` to the cached record for `id`. Subclasses can define
  // `_didReplaceResource` to react (e.g. clear draft state in rest-compat).
  _adoptResource(id) {
    if (id == null) {
      return;
    }
    const Klass = this.constructor;
    const cached = warpStore().peekRecord({
      type: Klass.type,
      id: String(id),
    });
    if (cached && cached !== this.#resource) {
      this.#resource = cached;
      this._didReplaceResource?.();
    }
    this._applyExtraAttributes(id);
  }

  updateFromJson(json) {
    if (json == null) {
      return this;
    }
    const Klass = this.constructor;
    const document = Klass.normalize(json);
    if (!document || Array.isArray(document.data)) {
      return this;
    }
    warpStore().push(document);
    this._adoptResource(document.data?.id);
    return this;
  }

  async save(data) {
    const Klass = this.constructor;
    const store = warpStore();
    const result = await store.request(Klass.builders.save(this, data));
    this._adoptResource(result.content?.data?.id);
    return this;
  }

  async destroy() {
    const Klass = this.constructor;
    const id = this.id;
    if (id == null) {
      return;
    }
    await warpStore().request(Klass.builders.delete(id));
  }

  // Call after `store.push` of an optimistic update — swaps a draft wrapper
  // to the now-cached record so subsequent reads see the pushed attributes.
  _adoptCacheRecord() {
    this._adoptResource(this.id);
  }
}

// Attach document-level `meta` keys to the returned array so legacy callers
// can read `result.grant_count` / `result.username` directly.
export function attachMeta(records, meta) {
  if (meta) {
    Object.assign(records, meta);
  }
  return records;
}

export async function requestMany(Klass, request) {
  const { content } = await warpStore().request(request);
  return attachMeta(
    (content?.data ?? []).map((r) => new Klass(r)),
    content?.meta
  );
}

export async function requestOne(Klass, request) {
  const { content } = await warpStore().request(request);
  return new Klass(content?.data);
}

// Install prototype getters/setters reading/writing `__resource` for each
// schema field. Subclass-defined getters (image, url, ...) take precedence —
// they're already on the prototype when this runs.
export function defineFieldForwarders(Klass, schema) {
  const proto = Klass.prototype;
  const fieldKinds = new Map();
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
    const descriptor = {
      configurable: true,
      get() {
        return this.__resource?.[name];
      },
    };
    // JSON:API stores ids as strings; coerce numeric ones back so
    // `badge.id === 1126` still works at Discourse call sites.
    if (kind === "@id") {
      descriptor.get = function () {
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
      descriptor.set = function (value) {
        if (this.__resource) {
          this.__resource[name] = value;
        }
      };
    }
    Object.defineProperty(proto, name, descriptor);
  }
}
