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
import type {
  RestModelAttrs,
  RestModelSaveResult,
  RestModelState,
  RestModelStoreAttrs,
  RestPayload,
} from "discourse/models/rest";
import type StoreService from "discourse/services/store";

/** Factory typing must accept subclasses with their own constructor arguments. */
type RestCompatModelClass = abstract new (...args: never[]) => RestCompatModel;

/**
 * Attrs bags handed to `create`, as opposed to cached records. Tracked by
 * identity because the two are indistinguishable by shape, and reading an
 * undeclared field off a cached record throws rather than returning undefined.
 */
const draftResources = new WeakSet<object>();

/**
 * Bridges Discourse's legacy `Store` + `RestModel` callsites to WarpRestModel.
 * Drop this layer (extend WarpRestModel directly) once a model's callers no
 * longer use `.get` / `.set` / `.setProperties` / `store.createRecord` /
 * `record.save` / `record.destroyRecord`.
 */
export default class RestCompatModel extends WarpRestModel<
  RestModelSaveResult<RestCompatModel>
> {
  /**
   * Identity by default; legacy `service:store._hydrate` calls this on cache
   * updates. Subclasses can override to massage JSON before it lands.
   */
  static munge(json: RestPayload): RestPayload {
    return json;
  }

  /**
   * Draft attrs go into a `trackedObject` so field reads/writes are reactive
   * — Glimmer templates rerender when callers do `bookmark.set("name", ...)`,
   * matching the old EmberObject behavior. Cached LegacyMode records have
   * their own signal-based reactivity.
   */
  static create<C extends RestCompatModelClass>(
    this: C,
    attrs?: RestModelAttrs<InstanceType<C>> | InstanceType<C>
  ): InstanceType<C>;

  /** Keeps static-side compatibility with subclasses that specialize `create`. */
  static create<C extends typeof RestCompatModel>(
    this: C,
    attrs?: RestModelAttrs<InstanceType<C>> | InstanceType<C>
  ): InstanceType<C>;

  static create(attrs: RestPayload & RestModelStoreAttrs = {}) {
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

  /** True while a legacy `save` or `update` request is in flight. */
  @tracked isSaving = false;

  /**
   * Subclasses override (e.g. `TagNotification` uses `"name"`).
   */
  primaryKey = "id";

  /**
   * `Store._build` stamps these onto the raw attrs. They are legacy bookkeeping
   * rather than schema fields, so — as in `RestModel` — they belong to the
   * wrapper. Reading them back through `__resource` works only while it is the
   * draft attrs bag: once the wrapper adopts a cached record, LegacyMode throws
   * on every field the schema doesn't declare, and `save()` reads `isNew`.
   */
  store: StoreService | undefined;

  /** The store type name the record was built under. */
  __type: string | undefined;

  /** `"new"` until the first legacy save creates the record. */
  @tracked __state: RestModelState | undefined;

  constructor(...args: ConstructorParameters<typeof WarpRestModel>) {
    super(...args);

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
    applyRegisteredFields(this, (name: string) => {
      const resource = this.__ownResource;
      const value = draftResources.has(resource!)
        ? resource?.[name]
        : (this as unknown as RestPayload)[name];
      if (value !== undefined) {
        return { value };
      }
    });

    // Fires `init` callbacks (see `addModelCallback`) with the create args
    // already in place, matching `RestModel`.
    applyModelCallbacks(modelNameFor(this), "init", this);
  }

  /**
   * True until `save()` / `updateFromJson()` swaps in the cached record —
   * `_adoptResource` replaces the draft attrs bag, which is never in the set.
   */
  get __isLocalDraft() {
    return draftResources.has(this.__ownResource!);
  }

  /**
   * Both "topicDetails" and "topic-details" resolve, and the plugin API keys
   * its registrations by whichever spelling was used. `constructor.type` would
   * apply a plugin's fields but silently drop its callbacks and save properties.
   */
  get #modelName() {
    return modelNameFor(this);
  }

  /** True until the first legacy save creates the record. */
  get isNew() {
    return this.__state === "new";
  }

  /** True once a legacy save has created the record. */
  get isCreated() {
    return this.__state === "created";
  }

  /** Reads a member, or a dotted path through `@ember/object`'s `get`. */
  get<K extends keyof this>(path: K): this[K];
  get(path: string): unknown;
  get(path: unknown): unknown {
    if (typeof path !== "string") {
      return undefined;
    }
    return emberGet(this, path as keyof this);
  }

  /**
   * Writes a field and returns the value. A draft stores it in its attrs bag;
   * a cached record goes through the field's forwarder.
   */
  set<K extends string, V extends K extends keyof this ? this[K] : unknown>(
    key: K,
    value: V
  ): V;

  set(key: string, value: unknown) {
    // Drafts: mutate the attrs bag directly. Cached records: route through
    // the prototype setter, which writes to the record's own field.
    if (this.__isLocalDraft) {
      this.__resource![key] = value;
      return value;
    }
    (this as unknown as RestPayload)[key] = value;
    return value;
  }

  /** Reads several members at once. */
  getProperties<K extends keyof this>(...keys: K[]): Pick<this, K>;
  getProperties(...keys: string[]): RestPayload;
  getProperties(...keys: string[]) {
    return emberGetProperties(this, ...keys);
  }

  /** Writes each key of `hash` through `set` and returns `hash`. */
  setProperties<T extends object>(
    hash: T & Partial<Pick<this, Extract<keyof T, keyof this>>>
  ): T;

  setProperties<T extends null | undefined>(hash: T): T;
  setProperties(hash: object | null | undefined) {
    if (!hash) {
      return hash;
    }
    for (const [key, value] of Object.entries(hash)) {
      this.set(key, value);
    }
    return hash;
  }

  /**
   * Runs before the legacy save path creates the record, with the outgoing
   * properties. This and the other three hooks come from `RestModel` and fire
   * on the legacy save path only — new code on the WarpDrive path uses
   * `addModelCallback`.
   */
  beforeCreate(props: object): void;
  beforeCreate() {}

  /** Runs after the legacy save path creates the record, with the adapter result. */
  afterCreate(result: RestModelSaveResult<RestCompatModel>): void;
  afterCreate() {}

  /** Runs before the legacy save path updates the record, with the outgoing properties. */
  beforeUpdate(props: object): void;
  beforeUpdate() {}

  /** Runs after the legacy save path updates the record, with the adapter result. */
  afterUpdate(result: RestModelSaveResult<RestCompatModel>): void;
  afterUpdate() {}

  /**
   * Legacy `RestModel#save`. Goes through the WarpDrive path when the subclass
   * defines `static builders.save`; the legacy adapter pipeline otherwise.
   */
  async save(data?: RestPayload): Promise<this | RestModelSaveResult<this>> {
    if (!(this.constructor as typeof RestCompatModel).builders?.save) {
      return this.isNew ? this._saveNew(data) : this.update(data);
    }

    const props = this.#withSaveProperties(data);
    // The base implementation always returns this wrapper, even when subclasses widen save.
    return this.#withCallbacks(
      this.isNew ? "Create" : "Update",
      props,
      () => super.save(props!) as Promise<this>
    );
  }

  /** Legacy `RestModel#update`: sends `props` through the store adapter and applies the response. */
  async update(props?: object): Promise<RestModelSaveResult<this>> {
    props = this.#withSaveProperties(props);
    return this.#withSaving(() => {
      this.beforeUpdate(props!);
      return this.#withCallbacks("Update", props, async () => {
        const res = (await this.store!.update(
          this.__type,
          (this as unknown as RestPayload)[this.primaryKey],
          props!
        )) as RestModelSaveResult<this>;
        const payload = (this.constructor as typeof RestCompatModel).munge(
          (res.payload || res.responseJson)!
        );
        if (payload && payload.success !== "OK") {
          this.setProperties(payload as RestModelAttrs<this>);
        }
        res.target = this;
        this.afterUpdate(res);
        return res;
      });
    });
  }

  /** Legacy `RestModel#destroyRecord`: deletes through the store adapter, wrapped with callbacks. */
  destroyRecord() {
    return this.#withCallbacks("Destroy", undefined, () =>
      this.store!.destroyRecord(this.__type, this)
    );
  }

  /**
   * `WarpRestModel#destroy` (builder-driven delete), wrapped with callbacks.
   */
  async destroy() {
    await this.#withCallbacks("Destroy", undefined, () => super.destroy());
  }

  /**
   * Runs `fn` between the registered `addModelCallback` before/after callbacks
   * for `kind` ("Create" | "Update" | "Destroy").
   */
  async #withCallbacks<T>(
    kind: "Create" | "Update" | "Destroy",
    props: object | undefined,
    fn: () => T | PromiseLike<T>
  ): Promise<T> {
    const modelName = this.#modelName;
    await applyModelCallbacks(modelName, `before${kind}`, this, props);
    const res = await fn();
    await applyModelCallbacks(modelName, `after${kind}`, this, res);
    return res;
  }

  /**
   * Merges plugin-registered save properties (see `addModelSaveProperty`) into
   * the outgoing payload.
   */
  #withSaveProperties<T extends object | undefined>(data: T): T {
    const extras = extraSavePropertiesFor(this.#modelName, this);
    return Object.keys(extras).length ? { ...data, ...extras } : data;
  }

  async #withSaving<T>(fn: () => T | PromiseLike<T>): Promise<T> {
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

  /** The legacy create path: posts `props` through the store adapter and applies the response. */
  async _saveNew(props?: object): Promise<RestModelSaveResult<this>> {
    props = this.#withSaveProperties(props);
    return this.#withSaving(() => {
      this.beforeCreate(props!);
      return this.#withCallbacks("Create", props, async () => {
        const adapter = this.store!.adapterFor(this.__type);
        // TODO(typescript-pending): adapter types only describe RestModel; remove the cast when wrappers are supported.
        const res = (await adapter.createRecord(
          this.store!,
          this.__type,
          props!
        )) as unknown as RestModelSaveResult<this>;
        if (res.payload) {
          this.setProperties(
            (this.constructor as typeof RestCompatModel).munge(
              res.payload
            ) as RestModelAttrs<this>
          );
          this.__state = "created";
        }
        res.target = this;
        this.afterCreate(res);
        return res;
      });
    });
  }
}
