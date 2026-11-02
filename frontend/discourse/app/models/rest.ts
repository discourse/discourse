import { tracked } from "@glimmer/tracking";
import { warn } from "@ember/debug";
import EmberObject from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { getOwner, setOwner } from "@ember/owner";
import { Promise } from "rsvp";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import {
  applyModelCallbacks,
  applyRegisteredFields,
  mergeSaveProperties,
  modelNameFor,
} from "discourse/lib/model-extensions";
import { enumerateTrackedEntries } from "discourse/lib/tracked-tools";
import type Site from "discourse/models/site";
import type TopicTrackingState from "discourse/models/topic-tracking-state";
import type SiteSettingsService from "discourse/services/site-settings";
import type StoreService from "discourse/services/store";

/** A JSON payload sent to or received from the server. */
export type RestPayload = Record<string, unknown>;

/** Lifecycle state the store assigns: `"new"` before the first save, `"created"` after. */
export type RestModelState = "new" | "created";

/** Members the store assigns when it builds a record. */
export interface RestModelStoreAttrs {
  store?: StoreService;
  __type?: string;
  __state?: RestModelState;
}

/**
 * Attributes accepted by `create`: the model's declared members keep their
 * types, the store-assigned members are typed, and other keys pass through,
 * since server payloads carry fields a model may not declare.
 */
export type RestModelAttrs<M> = Partial<M> &
  RestModelStoreAttrs & { [key: string]: unknown };

/**
 * A `RestModel` instance, matched structurally on a few base members so that
 * subclasses whose overrides conflict with `EmberObject`'s (such as a
 * Promise-returning `destroy`) still qualify.
 */
export type RestModelInstance = Pick<
  RestModel,
  "isNew" | "isCreated" | "primaryKey"
>;

/** A class whose instances are `RestModel`s. */
export type RestModelClass = abstract new (
  ...args: never[]
) => RestModelInstance;

/** The result of `save` and `update`, as returned by the adapter. */
export interface RestModelSaveResult<M extends RestModelInstance = RestModel> {
  payload?: RestPayload;
  responseJson?: RestPayload;
  /** `null` until the save completes, including while after-save hooks run. */
  target?: M | null;
  [key: string]: unknown;
}

function waitForCallbacks<T>(
  pending: PromiseLike<unknown> | undefined,
  next: () => PromiseLike<T>
): globalThis.Promise<T>;
function waitForCallbacks<T>(
  pending: PromiseLike<unknown> | undefined,
  next: () => T
): T | globalThis.Promise<T>;
function waitForCallbacks<T>(
  pending: PromiseLike<unknown> | undefined,
  next: () => T
) {
  return pending ? pending.then(next) : next();
}

export default class RestModel extends EmberObject {
  // Overwrite and JSON will be passed through here before `create` and `update`
  static munge(json: RestPayload, store?: StoreService): RestPayload;
  static munge(json: RestPayload) {
    return json;
  }

  static create<C extends RestModelClass>(
    this: C,
    attrs?: RestModelAttrs<InstanceType<C>>
  ): InstanceType<C>;

  static create(args?: RestPayload) {
    args = args || {};

    args.__munge = this.munge;
    const createArgs = this.munge(
      { ...args, ...Object.fromEntries(enumerateTrackedEntries(args)) },
      args.store as StoreService | undefined
    );

    // Some Discourse code calls `model.create()` directly without going through the
    // store. In that case the owner is not set, and injections will fail. This workaround ensures
    // the owner is always present. Eventually we should use the store for everything to fix this.
    const receivedOwner = getOwner(createArgs);
    if (
      !receivedOwner ||
      (receivedOwner as typeof receivedOwner & { isDestroyed?: boolean })
        .isDestroyed
    ) {
      setOwner(createArgs, getOwnerWithFallback());
    }

    return super.create(createArgs);
  }

  @tracked isSaving = false;

  primaryKey = "id";
  declare store: StoreService;
  declare site: Site;

  /** TODO(typescript-pending): the factory returns the settings instance without types; remove the mapped unknown shape when its return is typed. */
  declare siteSettings: {
    [K in keyof ReturnType<typeof SiteSettingsService.create>]: unknown;
  };
  declare topicTrackingState: TopicTrackingState;

  @tracked __state?: RestModelState;

  /** Assigned by the store; absent on models created directly. */
  declare __type?: string;
  declare __munge: (json: RestPayload) => RestPayload;

  constructor(...args: ConstructorParameters<typeof EmberObject>) {
    super(...args);

    // Defines plugin-registered fields as tracked properties, before the server
    // payload is assigned. See `addModelField`.
    applyRegisteredFields(this);
  }

  init(...args: Parameters<EmberObject["init"]>) {
    super.init(...args);

    // Fires `init` callbacks after the create args are assigned, so they see
    // the initial state. See `addModelCallback`.
    applyModelCallbacks(modelNameFor(this), "init", this);
  }

  @dependentKeyCompat
  get isNew() {
    return this.__state === "new";
  }

  @dependentKeyCompat
  get isCreated() {
    return this.__state === "created";
  }

  beforeCreate(props: object): void;
  beforeCreate() {}
  afterCreate(result: RestModelSaveResult): void;
  afterCreate() {}

  beforeUpdate(props: object): void;
  beforeUpdate() {}
  afterUpdate(result: RestModelSaveResult): void;
  afterUpdate() {}

  update(props?: object): globalThis.Promise<RestModelSaveResult<this>> {
    if (this.isSaving) {
      return Promise.reject();
    }

    // Subclasses that update without explicit props define `updateProperties`.
    props =
      props ||
      (this as this & { updateProperties(): RestPayload }).updateProperties();

    const modelName = modelNameFor(this);
    mergeSaveProperties(modelName, this, props);

    this.beforeUpdate(props);

    this.set("isSaving", true);
    return waitForCallbacks(
      applyModelCallbacks(modelName, "beforeUpdate", this, props),
      () =>
        this.store.update(
          this.__type,
          this.get(this.primaryKey as keyof this),
          props
        ) as globalThis.Promise<RestModelSaveResult<this>>
    )
      .then((res) => {
        const payload = this.__munge(
          (res.payload || res.responseJson) as RestPayload
        );

        if (payload.success === "OK") {
          warn("An update call should return the updated attributes", {
            id: "discourse.rest-model.update-attributes",
          });
          res = props as RestModelSaveResult<this>;
        }

        this.setProperties(payload);
        this.afterUpdate(res);
        return waitForCallbacks(
          applyModelCallbacks(modelName, "afterUpdate", this, res),
          () => {
            res.target = this;
            return res;
          }
        );
      })
      .finally(() => this.set("isSaving", false));
  }

  createProperties(): RestPayload {
    throw new Error(
      "You must overwrite `createProperties()` before saving a record"
    );
  }

  save(props?: object): globalThis.Promise<RestModelSaveResult<this>> {
    return this.isNew ? this._saveNew(props) : this.update(props);
  }

  destroyRecord(): globalThis.Promise<unknown> {
    return this.store.destroyRecord(this.__type, this);
  }

  _saveNew(props?: object): globalThis.Promise<RestModelSaveResult<this>> {
    if (this.isSaving) {
      return Promise.reject();
    }

    props = props || this.createProperties();

    const modelName = modelNameFor(this);
    mergeSaveProperties(modelName, this, props);

    this.beforeCreate(props);

    const adapter = this.store.adapterFor(this.__type);

    this.set("isSaving", true);
    return waitForCallbacks(
      applyModelCallbacks(modelName, "beforeCreate", this, props),
      () =>
        adapter.createRecord(this.store, this.__type, props) as Promise<
          RestModelSaveResult<this> | undefined
        >
    )
      .then((res) => {
        if (!res) {
          throw new Error("Received no data back from createRecord");
        }

        // We can get a response back without properties, for example
        // when a post is queued.
        if (res.payload) {
          this.setProperties(this.__munge(res.payload));
          this.set("__state", "created");
        }

        this.afterCreate(res);
        return waitForCallbacks(
          applyModelCallbacks(modelName, "afterCreate", this, res),
          () => {
            res.target = this;
            return res;
          }
        );
      })
      .finally(() => this.set("isSaving", false));
  }
}
