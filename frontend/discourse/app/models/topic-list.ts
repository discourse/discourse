import { tracked } from "@glimmer/tracking";
import EmberObject, { action, computed } from "@ember/object";
import { service } from "@ember/service";
import type { TrustedHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import { removeValuesFromArray } from "discourse/lib/array-tools";
import deprecated from "discourse/lib/deprecated";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import { applyValueTransformer } from "discourse/lib/transformer";
import type {
  CategoryFields,
  default as Category,
} from "discourse/models/category";
import RestModel, { type RestPayload } from "discourse/models/rest";
import type SessionService from "discourse/models/session";
import Site from "discourse/models/site";
import type {
  TopicBasicUser,
  TopicCreateAttrs,
  TopicPoster,
  TopicTag,
} from "discourse/models/topic";
import User, { type UserCreateAttrs } from "discourse/models/user";
import type StoreService from "discourse/services/store";
import Topic from "./topic.ts";

/** Primary groups are hydrated as plain EmberObjects, rather than Group models. */
export interface TopicListPrimaryGroup {
  id: number;
  name: string;
}

export interface TopicListFlairGroup extends TopicListPrimaryGroup {
  flair_url: string | null;
  flair_bg_color: string | null;
  flair_color: string | null;
}

/** Tag lists include details absent from the top-tags summary. */
export interface TopicListTag extends TopicTag {
  topic_count: number;
  staff: boolean;
  description: string | null;
  description_cooked: string | null;
  localizations?: {
    id: number;
    tag_id: number;
    locale: string;
    name: string | null;
    description: string | null;
    description_cooked: string | null;
  }[];
}

export interface TopicListFilterOption {
  name: string;
  description: string;
  type?: string;
  priority?: number;
  alias?: string;
  prefixes?: { name: string; description: string }[];
  delimiters?: { name: string; description: string }[];
}

/** List items have posters even when the array is empty. Hydration mutates these references. */
export type TopicListItem = TopicCreateAttrs<Topic> & {
  posters: TopicPoster[];
};

export interface TopicListData {
  topics: TopicListItem[];
  can_create_topic: boolean;
  filter: string;
  per_page: number;
  more_topics_url?: string;
  for_period?: string;
  shared_drafts?: TopicListItem[];
  categories?: CategoryFields[];
  top_tags?: TopicTag[];
  tags?: TopicListTag[];
  filter_option_info?: TopicListFilterOption[];
  filter_new_topic_ids?: number[];
}

/** The side-loaded roots may be omitted for empty lists. They remain on the model. */
export type TopicListUser = UserCreateAttrs &
  TopicBasicUser & { trust_level: number };

export interface TopicListEnvelope {
  topic_list: TopicListData;
  users?: TopicListUser[];
  primary_groups?: TopicListPrimaryGroup[];
  flair_groups?: TopicListFlairGroup[];
}

export interface TopicListParams {
  q?: string;
  order?: string;
  ascending?: boolean | string;
  subset?: string;
  [key: string]:
    | string
    | number
    | boolean
    | (string | number)[]
    | null
    | undefined;
}

/** Core client state and retained response data; plugins can augment this interface. */
export interface TopicListFields extends TopicListEnvelope {
  filter: string;
  params?: TopicListParams;
  listParams?: TopicListParams;
  loaded: boolean;
  can_create_topic: boolean;
  per_page: number;
  more_topics_url?: string;
  for_period?: string;
  sharedDrafts?: Topic[];
  inserted: unknown[];
  loadingMore?: boolean;
  hideCategory?: boolean;
  emptyState?: { title: string; body: string | TrustedHTML };
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface TopicList extends TopicListFields {}

function extractByKey<A extends { id: number }, M>(
  collection: A[] | undefined,
  klass: { create(attrs: A): M }
): Record<number, M | undefined> {
  const retval: Record<number, M | undefined> = {};
  if (isEmpty(collection)) {
    return retval;
  }

  collection!.forEach(function (item) {
    retval[item.id] = klass.create(item);
  });
  return retval;
}

/** Whether to show the category badge in topic lists. */
function displayCategoryInList(site: Site, category: Category | undefined) {
  if (category) {
    if (category.has_children) {
      return true;
    }

    const draftCategoryId = site.shared_drafts_category_id;
    if (draftCategoryId && category.id === draftCategoryId) {
      return true;
    }

    return false;
  }

  return true;
}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class TopicList extends RestModel {
  static topicsFrom(
    store: StoreService,
    result: TopicListEnvelope | null | undefined,
    opts?: { listKey?: "topics" | "shared_drafts" }
  ): Topic[] | undefined;

  static topicsFrom(
    store: StoreService,
    result: TopicListEnvelope | null | undefined,
    opts: { listKey?: "topics" | "shared_drafts" } | undefined
  ) {
    if (!result) {
      return;
    }

    opts = opts || {};
    // eslint-disable-next-line prefer-const -- Preserve the original declaration in this types-only port.
    let listKey = opts.listKey || "topics";

    // Stitch together our side loaded data

    const users = extractByKey(result.users, User);
    const groups = extractByKey<
      TopicListPrimaryGroup,
      EmberObject & TopicListPrimaryGroup
    >(result.primary_groups, EmberObject);

    if (result.topic_list.categories) {
      result.topic_list.categories.forEach((c) => {
        Site.current().updateCategory(c);
      });
    }

    const topics = result.topic_list[listKey]!.map((t) => {
      t.posters.forEach((p) => {
        p.user = users[p.user_id];
        p.extraClasses = p.extras;
        if (p.primary_group_id) {
          p.primary_group = groups[p.primary_group_id];
          if (p.primary_group) {
            p.extraClasses = `${p.extraClasses || ""} group-${
              p.primary_group.name
            }`;
          }
        }
      });

      if (t.participants) {
        t.participants.forEach((p) => (p.user = users[p.user_id]));
      }

      return store.createRecord("topic", t);
    });

    return applyValueTransformer("topic-list-topics-from", topics, {
      store,
      result,
      opts,
    });
  }

  static munge(json: RestPayload, store?: StoreService): RestPayload;
  static munge(
    json: RestPayload & TopicListEnvelope & Partial<TopicListFields>,
    store: StoreService
  ) {
    json.inserted = json.inserted || [];
    json.can_create_topic = json.topic_list.can_create_topic;
    json.more_topics_url = json.topic_list.more_topics_url;
    json.for_period = json.topic_list.for_period;
    json.loaded = true;
    json.per_page = json.topic_list.per_page;
    json.topics = this.topicsFrom(store, json)!;

    if (json.topic_list.shared_drafts) {
      json.sharedDrafts = this.topicsFrom(store, json, {
        listKey: "shared_drafts",
      });
    }

    return json;
  }

  static find(
    filter: string,
    params: TopicListParams
  ): globalThis.Promise<TopicList> {
    deprecated(
      `TopicList.find is deprecated. Use \`findFiltered("topicList")\` on the \`store\` service instead.`,
      {
        id: "discourse.topic-list-find",
        since: "3.1.0.beta5",
      }
    );

    // TODO(typescript-pending): remove this lookup assertion when getOwnerWithFallback publishes typed service lookups.
    const store = getOwnerWithFallback(this).lookup("service:store");
    return (store as StoreService).findFiltered("topicList", {
      filter,
      params,
    });
  }

  /** Hide the category when it has no children. */
  static hideUniformCategory(list: TopicList, category: Category | undefined) {
    list.set("hideCategory", !displayCategoryInList(list.site, category));
  }

  @service declare session: SessionService;

  @tracked loadingBefore: false | number = false;
  @autoTrackedArray topics!: Topic[];

  @computed("more_topics_url")
  get canLoadMore() {
    return !isEmpty(this.more_topics_url);
  }

  forEachNew(topics: Topic[], callback: (topic: Topic) => void) {
    const topicIds = new Set();
    this.topics.forEach((topic) => topicIds.add(topic.id));

    topics.forEach((topic) => {
      if (!topicIds.has(topic.id)) {
        callback(topic);
      }
    });
  }

  updateSortParams(order: string | undefined, ascending: boolean) {
    let params = { ...(this.params || {}) };

    if (params.q) {
      // search is unique, nothing else allowed with it
      params = { q: params.q };
    } else {
      params.order = order || params.order;
      params.ascending = ascending;
    }

    this.set("params", params);
  }

  updateNewListSubsetParam(subset: string) {
    let params = { ...(this.params || {}) };

    if (params.q) {
      params = { q: params.q };
    } else {
      params.subset = subset;
    }

    this.set("params", params);
  }

  @action
  loadMore(): globalThis.Promise<
    { moreTopicsUrl: string | undefined; newTopics: Topic[] } | undefined
  > {
    if (this.loadingMore) {
      return Promise.resolve();
    }

    let moreUrl = this.more_topics_url;
    if (moreUrl) {
      // eslint-disable-next-line prefer-const -- Preserve the original destructuring declaration in this types-only port.
      let [url, params] = moreUrl.split("?");

      // ensure we postfix with .json so username paths work
      // correctly
      if (!url!.match(/\.json$/)) {
        url += ".json";
      }

      moreUrl = url;
      if (params) {
        moreUrl += "?" + params;
      }

      this.set("loadingMore", true);

      // TODO(typescript-pending): ajax does not publish response types; remove the payload annotation when its response is generic.
      return ajax({ url: moreUrl }).then(
        async (result: TopicListEnvelope | undefined) => {
          let topicsAdded = 0;

          if (result) {
            // the new topics loaded from the server
            const newTopics = TopicList.topicsFrom(this.store, result)!;
            await Topic.applyTransformations(newTopics);

            this.forEachNew(newTopics, (t) => {
              t.set("highlight", topicsAdded++ === 0);
              this.topics.push(t);
            });

            this.setProperties({
              loadingMore: false,
              more_topics_url: result.topic_list.more_topics_url,
            });

            this.session.set("topicList", this);
            return { moreTopicsUrl: this.more_topics_url, newTopics };
          }
        }
      );
    } else {
      // Return a promise indicating no more results
      return Promise.resolve();
    }
  }

  /** Loads topics with these IDs before the current topics. */
  async loadBefore(topic_ids: number[], storeInSession?: boolean) {
    this.loadingBefore = topic_ids.length;

    try {
      const url = `/${this.filter}.json?topic_ids=${topic_ids.join(",")}`;

      // TODO(typescript-pending): ajax does not publish response types; remove the assertion when its response is generic.
      const result = (await ajax({
        url,
        data: this.params,
      })) as TopicListEnvelope;

      // refresh dupes
      removeValuesFromArray(
        this.topics,
        this.topics.filter((topic) => topic_ids.includes(topic.id))
      );

      let i = 0;
      this.forEachNew(TopicList.topicsFrom(this.store, result)!, (t) => {
        // highlight the first of the new topics so we can get a visual feedback
        t.set("highlight", true);
        this.topics.splice(i, 0, t);
        i++;
      });

      if (storeInSession) {
        this.session.set("topicList", this);
      }
    } finally {
      this.loadingBefore = false;
    }
  }
}
