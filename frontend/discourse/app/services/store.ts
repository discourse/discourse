import { untrack } from "@glimmer/validator";
import { warn } from "@ember/debug";
import { set } from "@ember/object";
import Service from "@ember/service";
import { underscore } from "@ember/string";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import { getRegister } from "discourse/lib/get-owner";
import { cleanNullQueryParams } from "discourse/lib/utilities";
import WeakValueMap from "discourse/lib/weak-value-map";
import type Category from "discourse/models/category";
import type PendingPost from "discourse/models/pending-post";
import type { default as Post, PostCreateAttrs } from "discourse/models/post";
import type PostStream from "discourse/models/post-stream";
import type PublishedPage from "discourse/models/published-page";
import RestModel, {
  type RestModelAttrs,
  type RestModelClass,
  type RestModelInstance,
  type RestModelSaveResult,
  type RestPayload,
} from "discourse/models/rest";
import ResultSet from "discourse/models/result-set";
import type Site from "discourse/models/site";
import type {
  default as Topic,
  TopicCreateAttrs,
} from "discourse/models/topic";
import type { default as User, UserCreateAttrs } from "discourse/models/user";
import type UserDraft from "discourse/models/user-draft";

/** Model instances by store type name. Plugins add theirs through module augmentation. */
export interface ModelRegistry {
  category: Category;
  "pending-post": PendingPost;
  post: Post;
  "post-stream": PostStream;
  "published-page": PublishedPage;
  site: Site;
  topic: Topic;
  user: User;
  "user-draft": UserDraft;
}

/**
 * Creation attributes by store type name, for models whose inputs differ from
 * their instance fields. Plugins add entries through module augmentation.
 */
export interface ModelCreateAttrsRegistry {
  post: PostCreateAttrs<Post>;
  topic: TopicCreateAttrs<Topic>;
  user: UserCreateAttrs<User>;
}

type ModelNameLowercaseLetter =
  | "a"
  | "b"
  | "c"
  | "d"
  | "e"
  | "f"
  | "g"
  | "h"
  | "i"
  | "j"
  | "k"
  | "l"
  | "m"
  | "n"
  | "o"
  | "p"
  | "q"
  | "r"
  | "s"
  | "t"
  | "u"
  | "v"
  | "w"
  | "x"
  | "y"
  | "z";

type ModelNameDigit = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9";

/** Keep original casing for the resolver's ASCII boundary rule, then lowercase once. */
type NormalizeModelNameCharacters<
  Name extends string,
  Previous extends string = "",
  Result extends string = "",
> = Name extends `${infer First}${infer Rest}`
  ? NormalizeModelNameCharacters<
      Rest,
      First,
      `${Result}${Previous extends ModelNameLowercaseLetter | ModelNameDigit
        ? First extends Uppercase<ModelNameLowercaseLetter>
          ? "-"
          : ""
        : ""}${First extends "." ? "/" : First extends "_" | " " ? "-" : First}`
    >
  : Lowercase<Result>;

/**
 * Normalizes literal model names as the resolver does. Open-ended strings remain
 * string because they have no required property keys and cannot prove a match.
 */
export type NormalizeModelName<K extends string> = K extends unknown
  ? Record<never, never> extends Record<K, never>
    ? string
    : NormalizeModelNameCharacters<
        K extends `${infer Name}:${string}` ? Name : K
      >
  : never;

type NormalizedModelRegistry<Registry> = {
  [K in keyof Registry & string as NormalizeModelName<K>]: Registry[K];
};

/** Unregistered names, including dynamic strings, fall back to the base REST model. */
export type ModelFor<K extends string> = K extends unknown
  ? NormalizeModelName<K> extends keyof NormalizedModelRegistry<ModelRegistry>
    ? NormalizedModelRegistry<ModelRegistry>[NormalizeModelName<K>]
    : RestModel
  : never;

/** Uses registered creation attributes, falling back to the model's declared fields. */
export type ModelCreateAttrsFor<K extends string> = K extends unknown
  ? NormalizeModelName<K> extends keyof NormalizedModelRegistry<ModelCreateAttrsRegistry>
    ? NormalizedModelRegistry<ModelCreateAttrsRegistry>[NormalizeModelName<K>]
    : RestModelAttrs<ModelFor<K>>
  : never;

/** The content property is supplied by the legacy array proxy at runtime. */
export type ResultSetOf<M> = ResultSet & { content: M[] };

type FindArgs = string | number | object | null | undefined;
type StoreRecord = RestModel & RestPayload;
type StoreResults = StoreRecord | ResultSetOf<StoreRecord>;
type ModelClass = RestModelClass &
  Pick<typeof RestModel, "munge"> & {
    create(attrs?: RestPayload): RestModelInstance;
    ExtrasClass?: new (extras: unknown) => object;
  };
type ModelFactory = Pick<ModelClass, "munge"> & {
  create(attrs?: RestPayload): RestModelInstance;
  class?: ModelClass;
};

/** Adapter operations used by the REST store and its models. */
export interface StoreAdapter {
  primaryKey: string;
  apiNameFor(type: string): string;
  findAll(
    store: StoreService,
    type: string,
    findArgs?: object
  ): Promise<RestPayload>;
  find(
    store: StoreService,
    type: string,
    findArgs?: FindArgs,
    opts?: object
  ): Promise<RestPayload>;
  findStale(
    store: StoreService,
    type: string,
    findArgs?: FindArgs,
    opts?: object
  ): StoreResults | undefined;
  cacheFind(
    store: StoreService,
    type: string,
    findArgs: FindArgs,
    opts: object | undefined,
    hydrated: StoreResults
  ): void;
  update(
    store: StoreService,
    type: string | undefined,
    id: unknown,
    attrs: object,
    /** Legacy callback supplied by the store even when the adapter ignores it. */
    callback: (
      result: Record<string, RestPayload> | undefined
    ) => Record<string, RestPayload> | undefined
  ): Promise<RestModelSaveResult<RestModelInstance>>;
  createRecord(
    store: StoreService,
    type: string | undefined,
    attrs: object
  ): Promise<RestModelSaveResult | undefined>;
  destroyRecord(
    store: StoreService,
    type: string | undefined,
    record: RestModelInstance & { get(key: string): unknown }
  ): Promise<unknown>;
  getPayload(
    method: string,
    data: object
  ): {
    method: string;
    data: object | string;
    contentType?: string;
  };
  cache?: boolean;
  afterFindAll?(
    results: ResultSetOf<StoreRecord> | undefined,
    helpers: {
      lookup(subType: string, id: unknown): StoreRecord | undefined;
    }
  ): ResultSetOf<StoreRecord> | undefined;
  applyTransformations?(
    results: Array<RestPayload | RestModel>
  ): PromiseLike<unknown> | void;
}

const _identityMap = new Map<
  string | undefined,
  WeakValueMap<unknown, StoreRecord>
>();

function getTypeMap(type: string | undefined) {
  let typeMap = _identityMap.get(type);
  if (!typeMap) {
    typeMap = new WeakValueMap();
    _identityMap.set(type, typeMap);
  }
  return typeMap;
}

// You should only call this if you're a test scaffold
function flushMap() {
  for (const typeMap of _identityMap.values()) {
    typeMap.clear();
  }
  _identityMap.clear();
}

function storeMap(type: string | undefined, id: unknown, obj: StoreRecord) {
  if (!id) {
    return;
  }
  getTypeMap(type).set(id, obj);
}

function fromMap(type: string | undefined, id: unknown) {
  return _identityMap.get(type)?.get(id);
}

function removeMap(type: string | undefined, id: unknown) {
  _identityMap.get(type)?.delete(id);
}

export default class StoreService extends Service {
  declare register: {
    lookup(name: string): StoreAdapter | undefined;
    lookupFactory(name: string): ModelFactory | undefined;
  };

  _plurals: Record<string, string> = {
    category: "categories",
    "post-reply": "post-replies",
    "post-reply-history": "post_reply_histories",
    reviewable_history: "reviewable_histories",
    claimed_by: "claimed_bies",
  };

  init(...args: Parameters<Service["init"]>) {
    super.init(...args);
    this.register = this.register || getRegister(this);
  }

  pluralize(thing: string) {
    return this._plurals[thing] || thing + "s";
  }

  addPluralization(thing: string, plural: string) {
    this._plurals[thing] = plural;
  }

  /** Resolves to undefined when the response lacks the collection key. */
  findAll<K extends string>(
    type: K,
    findArgs?: object
  ): Promise<ResultSetOf<ModelFor<K>> | undefined>;

  findAll(type: string, findArgs?: object) {
    const adapter = this.adapterFor(type);

    // eslint-disable-next-line @typescript-eslint/no-this-alias -- Preserve the lookup callback's receiver in this types-only port.
    const store = this;
    return adapter.findAll(this, type, findArgs).then(async (result) => {
      let results = this._resultSet(type, result);
      if (adapter.afterFindAll) {
        results = adapter.afterFindAll(results, {
          lookup(subType, id) {
            return store._lookupSubType(subType, type, id, result);
          },
        });
      }
      await adapter.applyTransformations?.([result]);
      return results;
    });
  }

  // Mostly for legacy, things like TopicList without ResultSets
  /** Builds a single model directly from the response, without a ResultSet. */
  findFiltered<K extends string>(
    type: K,
    findArgs: object
  ): Promise<ModelFor<K>>;

  findFiltered(type: string, findArgs: object) {
    const adapter = this.adapterFor(type);
    findArgs = cleanNullQueryParams(findArgs);
    return adapter
      .find(this, type, findArgs)
      .then((result) => this._build(type, result))
      .then(async (result) => {
        await adapter.applyTransformations?.([result]);
        return result;
      });
  }

  // See if the store can find stale data. We sometimes prefer to show stale data and
  // refresh it in the background.
  findStale(type: string, findArgs?: FindArgs, opts?: object) {
    const stale = this.adapterFor(type).findStale(this, type, findArgs, opts);
    return {
      hasResults: stale !== undefined,
      results: stale,
      refresh: () => this.find(type, findArgs, opts),
    };
  }

  /**
   * Object arguments (including null) request a ResultSet, which is undefined when
   * the response lacks the collection key; ids or omission request one model.
   */
  find<K extends string>(
    type: K,
    findArgs: object | null,
    opts?: object
  ): Promise<ResultSetOf<ModelFor<K>> | undefined>;

  find<K extends string>(
    type: K,
    findArgs?: string | number,
    opts?: object
  ): Promise<ModelFor<K>>;

  find<K extends string>(
    type: K,
    findArgs: FindArgs,
    opts?: object
  ): Promise<ModelFor<K> | ResultSetOf<ModelFor<K>> | undefined>;

  find(
    type: string,
    findArgs?: FindArgs,
    opts?: object
  ): Promise<RestModel | ResultSetOf<RestModel> | undefined> {
    const adapter = this.adapterFor(type);
    return adapter.find(this, type, findArgs, opts).then((result) => {
      let hydrated = this._hydrateFindResults(result, type, findArgs, opts);

      // A response missing the collection key leaves `hydrated` undefined; the
      // extras and cache paths below have always assumed it is present.
      if (result.extras) {
        let extras = result.extras;

        const extrasClass = this._extrasClass(type);
        if (extrasClass) {
          extras = new extrasClass(extras);
        }

        hydrated!.set("extras", extras);
      }

      if (adapter.cache) {
        const stale = adapter.findStale(this, type, findArgs, opts);
        hydrated = this._updateStale(stale, hydrated!, adapter.primaryKey);
        adapter.cacheFind(this, type, findArgs, opts, hydrated);
      }
      return hydrated;
    });
  }

  refreshResults(
    resultSet: ResultSetOf<RestModel> | Pick<RestModel, "set">,
    type: string,
    url: string
  ) {
    const adapter = this.adapterFor(type);
    return ajax(url).then((result: RestPayload) => {
      const typeName = underscore(this.pluralize(adapter.apiNameFor(type)));
      // The collection under the adapter's plural key contains server records.
      const content = (result[typeName] as RestPayload[]).map((obj) =>
        this._hydrate(type, obj, result)
      );

      // reset the content of the array
      resultSet instanceof ResultSet
        ? resultSet.content.splice(0, Infinity, ...content)
        : resultSet.set("content", content);
    });
  }

  appendResults(resultSet: ResultSetOf<RestModel>, type: string, url: string) {
    const adapter = this.adapterFor(type);
    return ajax(url).then((result: RestPayload) => {
      const typeName = underscore(this.pluralize(adapter.apiNameFor(type)));

      // Pagination metadata may be nested or returned alongside the collection.
      const pageTarget = (result.meta || result) as RestPayload;
      // These dynamically named fields carry the pagination count and URL.
      const totalRows = (pageTarget["total_rows_" + typeName] ||
        resultSet.totalRows) as number;
      const loadMoreUrl = pageTarget["load_more_" + typeName] as
        | string
        | null
        | undefined;
      // The collection under the adapter's plural key contains server records.
      const content = (result[typeName] as RestPayload[]).map((obj) =>
        this._hydrate(type, obj, result)
      );

      resultSet.totalRows = totalRows;
      resultSet.loadMoreUrl = loadMoreUrl;
      resultSet.content.push(...content);

      // If we've loaded them all, clear the load more URL
      if (!resultSet.canLoadMore) {
        resultSet.loadMoreUrl = null;
      }
    });
  }

  update(
    type: string | undefined,
    id: unknown,
    attrs: object
  ): globalThis.Promise<RestModelSaveResult<RestModelInstance>> {
    const adapter = this.adapterFor(type);
    return adapter.update(this, type, id, attrs, function (result) {
      // Directly created models can lack __type; retain the legacy key coercion.
      if (
        result &&
        result[type as string] &&
        result[type as string][adapter.primaryKey]
      ) {
        const oldRecord = fromMap(type, id);
        removeMap(type, id);
        // This legacy callback assumes the old identity-map entry still exists.
        storeMap(type, result[type as string][adapter.primaryKey], oldRecord!);
      }
      return result;
    });
  }

  /** Accepts registered creation attributes, or the model's declared fields by default. */
  createRecord<K extends string>(
    type: K,
    attrs?: ModelCreateAttrsFor<K>
  ): ModelFor<K>;

  createRecord(type: string, attrs?: RestPayload) {
    attrs = attrs || {};
    const adapter = this.adapterFor(type);
    return attrs[adapter.primaryKey]
      ? this._hydrate(type, attrs)
      : this._build(type, attrs);
  }

  destroyRecord(
    type: string | undefined,
    record: RestModelInstance & { get(key: string): unknown }
  ) {
    const adapter = this.adapterFor(type);

    // If the record is new, don't perform an Ajax call
    if (record.get("isNew")) {
      removeMap(type, record.get(adapter.primaryKey));
      return Promise.resolve(true);
    }

    return adapter.destroyRecord(this, type, record).then(function (result) {
      removeMap(type, record.get(adapter.primaryKey));
      return result;
    });
  }

  adapterFor(type: string | undefined): StoreAdapter {
    return (
      this.register.lookup("adapter:" + type) ||
      // The application registers the fallback adapter, including in test stores.
      this.register.lookup("adapter:rest")!
    );
  }

  _hydrateFindResults(
    result: RestPayload,
    type: string,
    findArgs: FindArgs,
    opts?: object
  ): StoreResults | undefined;

  _hydrateFindResults(result: RestPayload, type: string, findArgs: FindArgs) {
    if (typeof findArgs === "object") {
      return this._resultSet(type, result, findArgs);
    } else {
      const apiName = this.adapterFor(type).apiNameFor(type);
      // The adapter's singular key contains the record to hydrate.
      return this._hydrate(
        type,
        result[underscore(apiName)] as RestPayload,
        result
      );
    }
  }

  _updateStale(
    stale: StoreResults | undefined,
    hydrated: StoreResults,
    primaryKey: string
  ): StoreResults {
    if (!stale) {
      return hydrated;
    }

    // TODO(typescript-pending): cached models expose collection content dynamically;
    // remove these assertions when their collection shape is declared.
    const newValues = (hydrated.get("content") as StoreRecord[]).map((item) => {
      let staleItem = (stale as { content: StoreRecord[] }).content.find(
        (i) => i.primaryKey === item.get(primaryKey)
      );
      if (staleItem) {
        for (const [key, value] of Object.entries(
          Object.getOwnPropertyDescriptors(staleItem)
        )) {
          if (value.writable && value.enumerable) {
            staleItem.set(key, value.value);
          }
        }
      } else {
        staleItem = item;
      }
      return staleItem;
    });

    hydrated instanceof ResultSet
      ? hydrated.content.splice(0, Infinity, ...newValues)
      : hydrated.set("content", newValues);

    return hydrated;
  }

  _resultSet(
    type: string,
    result: RestPayload,
    findArgs?: object | null
  ): ResultSetOf<StoreRecord> | undefined {
    const adapter = this.adapterFor(type);
    const typeName = underscore(this.pluralize(adapter.apiNameFor(type)));

    if (!result[typeName]) {
      // eslint-disable-next-line no-console
      console.error(`JSON response is missing \`${typeName}\` key`, result);
      return;
    }

    // The collection under the adapter's plural key contains server records.
    const content = (result[typeName] as RestPayload[]).map((obj) =>
      this._hydrate(type, obj, result)
    );

    // Pagination metadata may be nested or returned alongside the collection.
    const pageTarget = (result.meta || result) as RestPayload;

    const createArgs: RestPayload & { content: StoreRecord[] } = {
      content,
      findArgs,
      totalRows: pageTarget["total_rows_" + typeName] || content.length,
      loadMoreUrl: pageTarget["load_more_" + typeName],
      refreshUrl: pageTarget["refresh_" + typeName],
      resultSetMeta: result.meta,
      store: this,
      __type: type,
    };

    if (result.extras) {
      let extras = result.extras;

      const extrasClass = this._extrasClass(type);
      if (extrasClass) {
        extras = new extrasClass(extras);
      }

      createArgs.extras = extras;

      for (const obj of content) {
        obj.extras = extras;
      }
    }

    // TODO(typescript-pending): create returns the legacy base type; remove this
    // assertion once ResultSet declares its subclass return and proxy content.
    return ResultSet.create(createArgs) as ResultSetOf<StoreRecord>;
  }

  _extrasClass(type: string) {
    const klass: ModelFactory =
      this.register.lookupFactory("model:" + type) || RestModel;
    return klass.class?.ExtrasClass;
  }

  _build(type: string, obj: RestPayload): StoreRecord {
    const adapter = this.adapterFor(type);
    obj.store = this;
    obj.__type = type;
    obj.__state = obj[adapter.primaryKey] ? "created" : "new";

    const klass: ModelFactory =
      this.register.lookupFactory("model:" + type) || RestModel;
    // Factory-created models carry dynamic server attributes not declared by RestModel.
    const model = klass.create(obj) as StoreRecord;

    storeMap(type, obj[adapter.primaryKey], model);
    return model;
  }

  _lookupSubType(
    subType: string,
    type: string,
    id: unknown,
    root: RestPayload
  ) {
    // Serializer metadata maps embedded relationship names to concrete model names.
    if (root.meta && (root.meta as { types?: Record<string, string> }).types) {
      subType =
        (root.meta as { types: Record<string, string> }).types[subType] ||
        subType;
    }

    const subTypeAdapter = this.adapterFor(subType);
    const pluralType = this.pluralize(subType);
    // Sideloaded collections contain server records, indexed below by their JSON ids.
    const collection = root[this.pluralize(subType)] as
      | RestPayload[]
      | undefined;
    if (collection) {
      const hashedProp = "__hashed_" + pluralType;
      // This per-payload index is populated here and may already hold hydrated records.
      let hashedCollection = root[hashedProp] as
        | Record<string, RestPayload>
        | undefined;
      if (!hashedCollection) {
        hashedCollection = {};
        collection.forEach(function (it) {
          // forEach runs synchronously after initialization; preserve JS property-key coercion.
          hashedCollection![it[subTypeAdapter.primaryKey] as string] = it;
        });
        root[hashedProp] = hashedCollection;
      }

      // Relationship ids index object properties using the existing JS key coercion.
      const found = hashedCollection[id as string];
      if (found) {
        const hydrated = this._hydrate(subType, found, root);
        hashedCollection[id as string] = hydrated;
        return hydrated;
      }
    }
  }

  _hydrateEmbedded(type: string, obj: RestPayload, root: RestPayload) {
    const adapter = this.adapterFor(type);
    Object.keys(obj).forEach((k) => {
      if (k === adapter.primaryKey) {
        return;
      }

      const m = /(.+)\_id(s?)$/.exec(k);
      if (m) {
        const subType = m[1];

        if (m[2]) {
          if (!Array.isArray(obj[k])) {
            warn(`Expected an array of resource ids for ${type}.${k}`, {
              id: "discourse.store.hydrate-embedded",
            });

            return;
          }

          const hydrated = obj[k]
            .map((id) => this._lookupSubType(subType, type, id, root))
            .filter((item) => item != null);

          obj[this.pluralize(subType)] = hydrated;
          if (hydrated.length !== 0) {
            delete obj[k];
          }
        } else {
          const hydrated = this._lookupSubType(subType, type, obj[k], root);
          if (hydrated) {
            obj[subType] = hydrated;
            delete obj[k];
          } else {
            set(obj, subType, null);
          }
        }
      }
    });
  }

  _hydrate(type: string, obj: RestPayload, root?: RestPayload): StoreRecord {
    if (!obj) {
      throw new Error("Can't hydrate " + type + " of `null`");
    }

    const adapter = this.adapterFor(type);

    const id = obj[adapter.primaryKey];
    if (!id) {
      throw new Error(
        `Can't hydrate ${type} without primaryKey: \`${adapter.primaryKey}\``
      );
    }

    root = root || obj;

    if (root.__rest_serializer === "1") {
      this._hydrateEmbedded(type, obj, root);
    }

    const existing = fromMap(type, id);
    if (existing === obj) {
      return existing;
    }

    if (existing) {
      delete obj[adapter.primaryKey];
      let klass = this.register.lookupFactory("model:" + type);

      if (klass && klass.class) {
        klass = klass.class;
      }

      if (!klass) {
        klass = RestModel;
      }

      const updatedProperties = klass.munge(obj);

      // When running property comparisons, we need to prevent Glimmer from creating tracking contexts
      // which would otherwise cause "already used in same computation" errors when the values update
      untrack(() => {
        // Only update properties whose values actually changed to optimize rerenders
        // If a property value is unchanged, remove it from the update list
        updatedProperties &&
          Object.keys(updatedProperties).forEach((key) => {
            if (
              key.startsWith("__") ||
              existing[key] === updatedProperties[key]
            ) {
              delete updatedProperties[key];
            }
          });
      });

      // Apply all property updates in a single batch to trigger just one rerender
      existing.setProperties(updatedProperties);

      obj[adapter.primaryKey] = id;

      return existing;
    }

    return this._build(type, obj);
  }
}

export { flushMap };
