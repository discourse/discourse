import { tracked } from "@glimmer/tracking";
import {
  get as emberGet,
  getProperties as emberGetProperties,
} from "@ember/object";
import { trackedObject } from "@ember/reactive/collections";
import { exposeExtraAttributes } from "discourse/data/extra-attributes";
import WarpRestModel from "discourse/data/warp-rest-model";
import {
  applyModelCallbacks,
  applyRegisteredFields,
  extraSavePropertiesFor,
  modelNameFor,
} from "discourse/lib/model-extensions";

// Attrs bags handed to `create`, as opposed to cached records. Tracked by
// identity because the two are indistinguishable by shape, and reading an
// undeclared field off a cached record throws rather than returning undefined.
const draftResources = new WeakSet();

// Bridges Discourse's legacy `Store` + `RestModel` callsites to WarpRestModel.
// Drop this layer (extend WarpRestModel directly) once a model's callers no
// longer use `.get` / `.set` / `.setProperties` / `store.createRecord` /
// `record.save` / `record.destroyRecord`.
export default class RestCompatModel extends WarpRestModel {
  // Identity by default; legacy `service:store._hydrate` calls this on cache
  // updates. Subclasses can override to massage JSON before it lands.
  static munge(json) {
    return json;
  }

  // Draft attrs go into a `trackedObject` so field reads/writes are reactive
  // — Glimmer templates rerender when callers do `bookmark.set("name", ...)`,
  // matching the old EmberObject behavior. Cached LegacyMode records have
  // their own signal-based reactivity.
  static create(attrs = {}) {
    // Re-wrapping an existing instance was a harmless copy under EmberObject;
    // the wrapper's attrs now live in a private resource, so a spread would
    // drop them all. Hand the instance back instead.
    if (attrs instanceof this) {
      return attrs;
    }

    const resource = trackedObject({ ...attrs });
    draftResources.add(resource);
    const wrapper = new this(resource);
    wrapper.store = attrs.store;
    wrapper.__type = attrs.__type;
    wrapper.__state = attrs.__state;
    // Legacy `create(json)` took arbitrary keys; only schema fields have
    // prototype forwarders, so expose the rest straight off the draft.
    exposeExtraAttributes(wrapper, resource);
    return wrapper;
  }

  @tracked isSaving = false;

  // Subclasses override (e.g. `TagNotification` uses `"name"`).
  primaryKey = "id";

  // `Store._build` stamps these onto the raw attrs. They are legacy bookkeeping
  // rather than schema fields, so — as in `RestModel` — they belong to the
  // wrapper. Reading them back through `__resource` works only while it is the
  // draft attrs bag: once the wrapper adopts a cached record, LegacyMode throws
  // on every field the schema doesn't declare, and `save()` reads `isNew`.
  store;
  __type;
  @tracked __state;

  constructor() {
    super(...arguments);

    // Defines plugin-registered fields (see `addModelField`) as tracked
    // properties on the wrapper. Plugin fields are outside the schema, so they
    // live here rather than in the cache, and a caller/server-provided value
    // wins over the registered default.
    //
    // Only a draft's attrs bag can be probed directly — it holds whatever the
    // caller passed. A cached record throws on any field its schema doesn't
    // declare, which is every plugin field, so go through the wrapper, where
    // the base constructor has already exposed the retained extras. Existence
    // is probed by reading rather than `in`: the `has` trap on a `trackedObject`
    // draft is unreliable, and an explicit `undefined` means omission here.
    //
    // Reads `__ownResource`, not `__resource`: subclasses override the latter to
    // resolve the resource from their own fields, which aren't initialized yet
    // during `super()`.
    applyRegisteredFields(this, (name) => {
      const resource = this.__ownResource;
      const value = draftResources.has(resource)
        ? resource?.[name]
        : this[name];
      if (value !== undefined) {
        return { value };
      }
    });

    // Fires `init` callbacks (see `addModelCallback`) with the create args
    // already in place, matching `RestModel`.
    applyModelCallbacks(modelNameFor(this), "init", this);
  }

  // True until `save()` / `updateFromJson()` swaps in the cached record —
  // `_adoptResource` replaces the draft attrs bag, which is never in the set.
  get __isLocalDraft() {
    return draftResources.has(this.__ownResource);
  }

  // Both "topicDetails" and "topic-details" resolve, and the plugin API keys
  // its registrations by whichever spelling was used. `constructor.type` would
  // apply a plugin's fields but silently drop its callbacks and save properties.
  get #modelName() {
    return modelNameFor(this);
  }

  get isNew() {
    return this.__state === "new";
  }

  get isCreated() {
    return this.__state === "created";
  }

  get(path) {
    if (typeof path !== "string") {
      return undefined;
    }
    return emberGet(this, path);
  }

  set(key, value) {
    // Drafts: mutate the attrs bag directly. Cached records: route through
    // the prototype setter, which writes to the record's own field.
    if (this.__isLocalDraft) {
      this.__resource[key] = value;
      return value;
    }
    this[key] = value;
    return value;
  }

  getProperties(...keys) {
    return emberGetProperties(this, ...keys);
  }

  setProperties(hash) {
    if (!hash) {
      return hash;
    }
    for (const [key, value] of Object.entries(hash)) {
      this.set(key, value);
    }
    return hash;
  }

  // Subclass hooks from `RestModel`. Fired by the legacy save path only — new
  // code on the WarpDrive path uses `addModelCallback`.
  beforeCreate() {}
  afterCreate() {}

  beforeUpdate() {}
  afterUpdate() {}

  // Legacy `RestModel#save`. If the subclass defines `static builders.save`,
  // delegate to `WarpRestModel.save` (builder-driven, WarpDrive path);
  // otherwise branch on `isNew` and use the legacy adapter pipeline.
  async save(data) {
    if (!this.constructor.builders?.save) {
      return this.isNew ? this._saveNew(data) : this.update(data);
    }

    const props = this.#withSaveProperties(data);
    return this.#withCallbacks(this.isNew ? "Create" : "Update", props, () =>
      super.save(props)
    );
  }

  // Runs `fn` between the registered `addModelCallback` before/after callbacks
  // for `kind` ("Create" | "Update" | "Destroy"), passing the request props to
  // the before callbacks and `fn`'s result to the after callbacks.
  async #withCallbacks(kind, props, fn) {
    const modelName = this.#modelName;
    await applyModelCallbacks(modelName, `before${kind}`, this, props);
    const res = await fn();
    await applyModelCallbacks(modelName, `after${kind}`, this, res);
    return res;
  }

  // Merges plugin-registered save properties (see `addModelSaveProperty`) into
  // the outgoing payload. Returns `data` untouched when none are registered.
  #withSaveProperties(data) {
    const extras = extraSavePropertiesFor(this.#modelName, this);
    return Object.keys(extras).length ? { ...data, ...extras } : data;
  }

  async _saveNew(props) {
    props = this.#withSaveProperties(props);
    return this.#withSaving(() => {
      this.beforeCreate(props);
      return this.#withCallbacks("Create", props, async () => {
        const adapter = this.store.adapterFor(this.__type);
        const res = await adapter.createRecord(this.store, this.__type, props);
        if (res.payload) {
          this.setProperties(this.constructor.munge(res.payload));
          this.__state = "created";
        }
        res.target = this;
        this.afterCreate(res);
        return res;
      });
    });
  }

  async update(props) {
    props = this.#withSaveProperties(props);
    return this.#withSaving(() => {
      this.beforeUpdate(props);
      return this.#withCallbacks("Update", props, async () => {
        const res = await this.store.update(
          this.__type,
          this[this.primaryKey],
          props
        );
        const payload = this.constructor.munge(res.payload || res.responseJson);
        if (payload && payload.success !== "OK") {
          this.setProperties(payload);
        }
        res.target = this;
        this.afterUpdate(res);
        return res;
      });
    });
  }

  destroyRecord() {
    return this.#withCallbacks("Destroy", undefined, () =>
      this.store.destroyRecord(this.__type, this)
    );
  }

  // `WarpRestModel#destroy` (builder-driven delete), wrapped with callbacks.
  async destroy() {
    await this.#withCallbacks("Destroy", undefined, () => super.destroy());
  }

  async #withSaving(fn) {
    if (this.isSaving) {
      return Promise.reject(new Error("model is already saving"));
    }
    this.isSaving = true;
    try {
      return await fn();
    } finally {
      this.isSaving = false;
    }
  }
}
