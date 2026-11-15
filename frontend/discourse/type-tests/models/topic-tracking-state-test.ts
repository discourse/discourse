import type EmberObject from "@ember/object";
import { expectTypeOf } from "expect-type";
import type Category from "discourse/models/category";
import type CategoryList from "discourse/models/category-list";
import type RestModel from "discourse/models/rest";
import type Topic from "discourse/models/topic";
import type TopicList from "discourse/models/topic-list";
import TopicTrackingState, {
  startTracking,
} from "discourse/models/topic-tracking-state";
import type {
  default as StoreService,
  ModelFor,
} from "discourse/services/store";

declare const store: StoreService;
declare const tracking: TopicTrackingState;
declare const category: Category;
declare const topic: Topic;
declare const topicList: TopicList;
declare const categoryList: CategoryList;
declare const rest: RestModel;

/* Registration and injection. */

expectTypeOf(tracking).toExtend<EmberObject>();
expectTypeOf(tracking).not.toBeAny();
expectTypeOf<
  ModelFor<"topic-tracking-state">
>().toEqualTypeOf<TopicTrackingState>();
expectTypeOf(
  store.createRecord("topic-tracking-state", {})
).toEqualTypeOf<TopicTrackingState>();
expectTypeOf(rest.topicTrackingState).toEqualTypeOf<TopicTrackingState>();
startTracking(tracking);

/* Seed: preloaded report rows and channel cursors. */

tracking.loadStates([
  {
    topic_id: 1,
    highest_post_number: 1,
    last_read_post_number: null,
    created_at: "2026-10-27T23:20:03.749Z",
    category_id: 2,
    is_category_topic: false,
    notification_level: null,
    created_in_new_period: true,
    treat_as_new_topic_start_date: "2026-10-27T23:20:02.657Z",
    tags: null,
  },
  // Tagging enabled: report tags carry only ids.
  {
    topic_id: 2,
    highest_post_number: 3,
    last_read_post_number: 1,
    category_id: 2,
    notification_level: 2,
    created_in_new_period: true,
    tags: [{ id: 5 }],
  },
]);
// @ts-expect-error report rows are keyed by numeric topic ids
tracking.loadStates([{ topic_id: "1", highest_post_number: 1 }]);
// The preload resolves to null when the key is missing.
tracking.loadStates(null);
tracking.establishChannels({ "/latest": 0, "/new": 0, "/unread/7": 43 });
tracking.establishChannels();

/* Live messages. */

tracking._processChannelPayload({
  topic_id: 1,
  message_type: "new_topic",
  payload: {
    last_read_post_number: null,
    highest_post_number: 1,
    created_at: "2026-10-27T23:20:03.749Z",
    category_id: 2,
    archetype: "regular",
    created_in_new_period: true,
    tags: [],
  },
});
tracking._processChannelPayload({
  topic_id: 1,
  message_type: "latest",
  payload: {
    bumped_at: "2026-10-27T23:20:03.749Z",
    category_id: 2,
    archetype: "regular",
  },
});
tracking._processChannelPayload({
  topic_id: 1,
  message_type: "unread",
  payload: {
    highest_post_number: 3,
    updated_at: "2026-10-27T23:20:04.569Z",
    created_at: "2026-10-27T23:20:05.580Z",
    category_id: 2,
    archetype: "regular",
    tags: [{ id: 5 }],
  },
});
tracking._processChannelPayload({
  topic_id: 1,
  message_type: "read",
  payload: {
    last_read_post_number: 2,
    notification_level: null,
    highest_post_number: 3,
  },
});
tracking._processChannelPayload({ topic_id: 1, message_type: "muted" });
// Dismissals carry no outer topic id.
tracking._processChannelPayload({
  message_type: "dismiss_new",
  payload: { topic_ids: [1] },
});
tracking._processChannelPayload({
  topic_id: 1,
  message_type: "read",
  payload: {
    // @ts-expect-error read positions are numbers
    last_read_post_number: "2",
    notification_level: null,
    highest_post_number: 3,
  },
});
tracking._processChannelPayload({
  message_type: "dismiss_new_posts",
  // @ts-expect-error dismissed ids are numbers
  payload: { topic_ids: ["1"] },
});
tracking.onDeleteMessage({ topic_id: 1, message_type: "delete" });
tracking.onRecoverMessage({ topic_id: 1, message_type: "recover" });
tracking.onDestroyMessage({ topic_id: 1, message_type: "destroy" });

/* State. */

expectTypeOf(tracking.messageCount).toEqualTypeOf<number>();
expectTypeOf(tracking.incomingCount).toEqualTypeOf<number>();
// Unset until tracking starts.
expectTypeOf(tracking.newIncoming).toEqualTypeOf<number[] | undefined>();
expectTypeOf(tracking.hasIncoming).toEqualTypeOf<boolean>();
expectTypeOf(tracking.filter).toEqualTypeOf<string | undefined>();
expectTypeOf(tracking.filterCategory).toEqualTypeOf<Category | undefined>();
expectTypeOf(tracking.filterTagName).toEqualTypeOf<string | undefined>();
expectTypeOf(tracking.mutedTopics).toEqualTypeOf<
  { topicId: number; createdAt: number }[]
>();
expectTypeOf(tracking.states.size).toEqualTypeOf<number>();
tracking.states.clear();

const state = tracking.findState(1);
expectTypeOf(state?.last_read_post_number).toEqualTypeOf<
  number | null | undefined
>();
expectTypeOf(state?.notification_level).toEqualTypeOf<
  number | null | undefined
>();
expectTypeOf(state?.is_seen).toEqualTypeOf<boolean | undefined>();
expectTypeOf(state?.deleted).toEqualTypeOf<boolean | undefined>();
tracking.findState("t1");
tracking.findState(topic);

/* Counting. */

expectTypeOf(tracking.countNew()).toEqualTypeOf<number>();
expectTypeOf(
  tracking.countUnread({ categoryId: 2, tagId: 5, noSubcategories: true })
).toEqualTypeOf<number>();
expectTypeOf(
  tracking.countNewAndUnread({
    categoryId: 2,
    customFilterFn: (entry) => entry.topic_id === 1,
  })
).toEqualTypeOf<number>();
expectTypeOf(
  tracking.lookupCount({ type: "latest", category, noSubcategories: false })
).toEqualTypeOf<number | undefined>();
expectTypeOf(tracking.countCategory(2, 5)).toEqualTypeOf<number>();
tracking.forEachTracked((entry, isNew, isUnread) => {
  expectTypeOf(entry.topic_id).not.toBeAny();
  // The classifiers pass partial-state values through `&&`, so neither is a strict boolean.
  expectTypeOf(isNew).not.toBeAny();
  expectTypeOf(isUnread).not.toBeAny();
});

/* Listeners. */

const callbackId = tracking.onStateChange(() => {});
expectTypeOf(callbackId).toEqualTypeOf<string>();
tracking.offStateChange(callbackId);
// @ts-expect-error listeners are called with no arguments
tracking.onStateChange((changed: string) => changed);

/* Lists and incoming topics. */

tracking.sync(topicList, topicList.filter, { order: "posts" });
tracking.sync(categoryList, "categories");
tracking.updateTopics(topicList.topics);
tracking.trackIncoming("all");
tracking.trackIncoming("latest", { tagId: 5 });
tracking.resetTracking();
tracking.clearIncoming([1, 2]);
tracking.removeTopics([1]);
tracking.updateSeen(1, 2);
tracking.modifyState("t1", { topic_id: 1, last_read_post_number: 1 });
tracking.modifyStateProp(2, "last_read_post_number", 3);

/* Extension data stays unknown. */

tracking.states.set("t1", { id: 1 });
tracking.modifyState(1, { topic_id: 1, extension_value: { enabled: true } });
tracking.modifyStateProp(1, "extension_value", ["value"]);
expectTypeOf(tracking.findState(1)?.extension_value).toBeUnknown();

/* Callback receivers and classifier results. */

tracking.countNew({
  customFilterFn(entry) {
    expectTypeOf(this).toEqualTypeOf<TopicTrackingState>();
    expectTypeOf(entry.topic_id).toEqualTypeOf<number | undefined>();
    return entry;
  },
});
tracking.forEachTracked(
  (entry, isNew, isUnread) => {
    expectTypeOf(entry.topic_id).toEqualTypeOf<number | undefined>();
    expectTypeOf(isNew).toEqualTypeOf<boolean | undefined>();
    expectTypeOf(isUnread).toEqualTypeOf<boolean>();
  },
  { includeAll: true }
);

/* Nullable reads and payload-free messages. */

tracking._processChannelPayload({ topic_id: 1, message_type: "unmuted" });
tracking._processChannelPayload({
  message_type: "dismiss_new_posts",
  payload: { topic_ids: [] },
});
tracking._processChannelPayload({
  topic_id: 1,
  message_type: "read",
  payload: {
    last_read_post_number: null,
    notification_level: null,
    highest_post_number: null,
  },
});
expectTypeOf(tracking.findState(1)?.highest_post_number).toEqualTypeOf<
  number | null | undefined
>();

/* Structural lists and loose keys. */

tracking.sync({ topics: [], more_topics_url: undefined }, "categories");
tracking.sync({ topics: undefined }, "categories");
tracking.establishChannels(null);
tracking.findState("123");
tracking.findState("contains-t");
expectTypeOf(tracking.getSubCategoryIds(null)).toEqualTypeOf<
  number[] | Set<number>
>();

/* Stored entries keep list-derived tag details. */

tracking.modifyState(1, {
  tags: [{ id: 5, name: "support", slug: "support" }],
});
expectTypeOf(tracking.findState(1)?.tags?.[0]?.name).toEqualTypeOf<
  string | undefined
>();
expectTypeOf(tracking.findState(1)?.tags?.[0]?.slug).toEqualTypeOf<
  string | undefined
>();
