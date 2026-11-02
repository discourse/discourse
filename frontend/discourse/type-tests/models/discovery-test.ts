import type EmberObject from "@ember/object";
import type RouterService from "@ember/routing/router-service";
import type { TrustedHTML } from "@ember/template";
import { expectTypeOf } from "expect-type";
import type LegacyArrayLikeObject from "discourse/lib/legacy-array-like-object";
import type { withPluginApi } from "discourse/lib/plugin-api";
import type Category from "discourse/models/category";
import CategoryList from "discourse/models/category-list";
import NavItem, {
  addNavItem,
  clearNavItems,
  customNavItemHref,
  ExtraNavItem,
  extraNavItemProperties,
  type NavigationBarItem,
  type NavItemOptions,
} from "discourse/models/nav-item";
import type RestModel from "discourse/models/rest";
import type {
  default as Topic,
  TopicFeaturedUser,
  TopicParticipant,
  TopicPoster,
} from "discourse/models/topic";
import TopicList, { type TopicListEnvelope } from "discourse/models/topic-list";
import type User from "discourse/models/user";
import type {
  default as StoreService,
  ModelFor,
} from "discourse/services/store";

declare const store: StoreService;
declare const list: TopicList;
declare const topic: Topic;
declare const category: Category;
declare const navItem: NavItem;
declare const extra: ExtraNavItem;
declare const categoryList: CategoryList;
declare const html: TrustedHTML;
declare const user: User;
declare const options: NavItemOptions;
declare const api: Parameters<Parameters<typeof withPluginApi>[0]>[0];

/* Store registration: every spelling callers use resolves to the class. */

expectTypeOf<ModelFor<"topic-list">>().toEqualTypeOf<TopicList>();
expectTypeOf<ModelFor<"topicList">>().toEqualTypeOf<TopicList>();
expectTypeOf<ModelFor<"nav-item">>().toEqualTypeOf<NavItem>();
expectTypeOf(
  store.findFiltered("topicList", { filter: "latest", params: {} })
).resolves.toEqualTypeOf<TopicList>();
expectTypeOf(
  store.createRecord("nav-item", { name: "latest", hasIcon: false })
).toEqualTypeOf<NavItem>();

/* TopicList: hydrated state. */

expectTypeOf(list).toExtend<RestModel>();
expectTypeOf(list).not.toBeAny();
expectTypeOf(list.topics).toEqualTypeOf<Topic[]>();
expectTypeOf(list.sharedDrafts).toEqualTypeOf<Topic[] | undefined>();
// Holds the number of topics being reloaded while a reload runs.
expectTypeOf(list.loadingBefore).toEqualTypeOf<false | number>();
expectTypeOf(list.canLoadMore).toEqualTypeOf<boolean>();
// Omitted when there is no next page.
expectTypeOf(list.more_topics_url).toEqualTypeOf<string | undefined>();
expectTypeOf(list.for_period).toEqualTypeOf<string | undefined>();
expectTypeOf(list.per_page).toEqualTypeOf<number>();
expectTypeOf(list.can_create_topic).toEqualTypeOf<boolean>();
expectTypeOf(list.filter).toEqualTypeOf<string>();
expectTypeOf(list.loaded).toEqualTypeOf<boolean>();
expectTypeOf(list.params).not.toBeAny();
list.loadingMore = true;
list.hideCategory = false;
list.emptyState = { title: "Nothing here", body: "Come back later" };
list.emptyState = { title: "Nothing here", body: html };

/* TopicList: the raw envelope stays available. */

expectTypeOf(list.topic_list.filter_new_topic_ids).toEqualTypeOf<
  number[] | undefined
>();
expectTypeOf(list.topic_list.top_tags).toEqualTypeOf<
  { id: number; name: string; slug: string }[] | undefined
>();
expectTypeOf(list.topic_list.filter_option_info).not.toBeAny();
expectTypeOf<
  NonNullable<TopicList["topic_list"]["tags"]>[number]["description"]
>().toEqualTypeOf<string | null>();
expectTypeOf(list.users).not.toBeAny();
expectTypeOf(list.primary_groups).toEqualTypeOf<
  { id: number; name: string }[] | undefined
>();

/* TopicList: methods. */

expectTypeOf(list.loadMore()).resolves.toEqualTypeOf<
  { moreTopicsUrl: string | undefined; newTopics: Topic[] } | undefined
>();
expectTypeOf(list.loadBefore([1, 2], true)).resolves.toEqualTypeOf<void>();
list.loadBefore([1]);
list.updateSortParams("posts", true);
list.updateSortParams(undefined, false);
list.updateNewListSubsetParam("topics");
list.forEachNew([topic], (t) => expectTypeOf(t).toEqualTypeOf<Topic>());

/* TopicList: statics. */

expectTypeOf(TopicList.topicsFrom(store, list)).toEqualTypeOf<
  Topic[] | undefined
>();
TopicList.topicsFrom(store, list, { listKey: "shared_drafts" });
TopicList.hideUniformCategory(list, category);
TopicList.hideUniformCategory(list, undefined);
expectTypeOf(TopicList.find("latest", {})).resolves.toEqualTypeOf<TopicList>();

/* Topic posters and participants are hydrated by the list. */

type Poster = NonNullable<Topic["posters"]>[number];
expectTypeOf<Poster["user_id"]>().toEqualTypeOf<number>();
expectTypeOf<Poster["extras"]>().toEqualTypeOf<string | null>();
expectTypeOf<Poster["description"]>().toEqualTypeOf<string | null>();
expectTypeOf<Poster["primary_group_id"]>().toEqualTypeOf<number | null>();
expectTypeOf<Poster["user"]>().toEqualTypeOf<User | undefined>();
expectTypeOf<
  NonNullable<Poster["primary_group"]>["name"]
>().toEqualTypeOf<string>();
type Participant = NonNullable<Topic["participants"]>[number];
expectTypeOf<Participant["user"]>().toEqualTypeOf<User | undefined>();
expectTypeOf(topic.lastPoster?.extras).toEqualTypeOf<
  string | null | undefined
>();
expectTypeOf(topic.featuredUsers).not.toBeAny();

/* NavItem. */

expectTypeOf(navItem).toExtend<EmberObject>();
expectTypeOf(
  NavItem.fromText("latest", { category })
).toEqualTypeOf<NavItem | null>();
NavItem.fromText("latest");
expectTypeOf(
  NavItem.buildList(category, { noSubcategories: true })
).toEqualTypeOf<NavItem[]>();
NavItem.buildList(undefined);
expectTypeOf(
  NavItem.pathFor("latest", { category, noSubcategories: true })
).toEqualTypeOf<string>();
NavItem.pathFor("latest", { tag: { id: 1, slug: "support" } });
expectTypeOf(navItem.name).toEqualTypeOf<string>();
expectTypeOf(navItem.filterType).toEqualTypeOf<string>();
navItem.filterType = "new";
expectTypeOf(navItem.title).toEqualTypeOf<string>();
navItem.title = "Custom title";
expectTypeOf(navItem.displayName).toEqualTypeOf<string>();
navItem.displayName = "Custom name";
expectTypeOf(navItem.href).toEqualTypeOf<string>();
expectTypeOf(navItem.filterMode).toEqualTypeOf<string>();
// Tracking has no count for some filters.
expectTypeOf(navItem.count).toEqualTypeOf<number | undefined>();
expectTypeOf(navItem.category).toEqualTypeOf<Category | undefined>();
expectTypeOf(navItem.noSubcategories).toEqualTypeOf<boolean | undefined>();
// The current-user service is registered as null for anonymous visitors.
expectTypeOf(navItem.currentUser).toEqualTypeOf<User | null>();

/* ExtraNavItem: plugins write href and count directly. */

expectTypeOf(extra).toExtend<NavItem>();
expectTypeOf(
  ExtraNavItem.create({ name: "votes" })
).toEqualTypeOf<ExtraNavItem>();
extra.href = "/latest?order=votes";
extra.count = 2;
expectTypeOf(extra.count).toEqualTypeOf<number>();
extra.customFilter = (filterCategory) => !filterCategory;
extra.customFilter = null;

/* Navigation registration APIs. */

addNavItem({
  name: "votes",
  before: "top",
  customFilter: (filterCategory, args) => !!filterCategory || !!args,
  customHref: (filterCategory) => (filterCategory ? "/c/votes" : "/votes"),
  forceActive: () => false,
});
addNavItem({ name: "subscribe", displayName: "Subscribe", href: "/s" });
extraNavItemProperties((filterType) => ({ hasIcon: filterType === "new" }));
customNavItemHref((item) => {
  expectTypeOf(item).toEqualTypeOf<NavItem>();
  return item.name === "latest" ? "/custom" : undefined;
});
clearNavItems();

/* CategoryList. */

expectTypeOf(categoryList).toExtend<LegacyArrayLikeObject<Category>>();
expectTypeOf(categoryList.content).toEqualTypeOf<Category[]>();
expectTypeOf(
  CategoryList.create({
    store,
    categories: [category],
    parentCategory: null,
    can_create_category: true,
    can_create_topic: true,
  })
).toEqualTypeOf<CategoryList>();
expectTypeOf(CategoryList.create()).toEqualTypeOf<CategoryList>();
// @ts-expect-error categories hold Category records
CategoryList.create({ categories: ["x"] });
expectTypeOf(
  CategoryList.categoriesFrom(store, {}, category)
).toEqualTypeOf<CategoryList>();
CategoryList.categoriesFrom(store, undefined);
expectTypeOf(CategoryList.list(store)).resolves.toEqualTypeOf<CategoryList>();
CategoryList.list(store, category);
expectTypeOf(categoryList.can_create_category).toEqualTypeOf<
  boolean | undefined
>();
expectTypeOf(categoryList.page).toEqualTypeOf<number>();
expectTypeOf(categoryList.isLoading).toEqualTypeOf<boolean>();
expectTypeOf(categoryList.fetchedLastPage).toEqualTypeOf<boolean>();
expectTypeOf(categoryList.parentCategory).toEqualTypeOf<
  Category | null | undefined
>();
// Only the combined categories-and-topics page supplies topics.
expectTypeOf(categoryList.topics).toEqualTypeOf<Topic[] | undefined>();
expectTypeOf(categoryList.categories).toEqualTypeOf<Category[]>();
expectTypeOf(categoryList.loadMore()).resolves.toEqualTypeOf<void>();

/* Subclasses keep their own factories. */

expectTypeOf<typeof TopicList>().toExtend<typeof RestModel>();
expectTypeOf<typeof CategoryList>().toExtend<
  typeof LegacyArrayLikeObject<Category>
>();
expectTypeOf<typeof ExtraNavItem>().toExtend<typeof NavItem>();

class SpecializedCategoryList extends CategoryList {
  declare clientLabel: string;
}
class SpecializedExtraNavItem extends ExtraNavItem {
  declare clientLabel: string;
}
class SpecializedTopicList extends TopicList {
  declare clientLabel: string;
}
expectTypeOf(
  SpecializedCategoryList.create({ categories: [category], clientLabel: "x" })
).toEqualTypeOf<SpecializedCategoryList>();
expectTypeOf(
  SpecializedExtraNavItem.create({ name: "x", clientLabel: "x" })
).toEqualTypeOf<SpecializedExtraNavItem>();
expectTypeOf(
  SpecializedTopicList.create()
).toEqualTypeOf<SpecializedTopicList>();

/* Envelopes and hydrated references. */

// Empty lists omit side-loaded roots. Shared drafts use the same topic item contract.
const empty: TopicListEnvelope = {
  topic_list: {
    topics: [],
    filter: "latest",
    can_create_topic: false,
    per_page: 30,
  },
};
expectTypeOf(empty.users).not.toBeAny();
expectTypeOf<TopicListEnvelope["flair_groups"]>().toEqualTypeOf<
  | {
      id: number;
      name: string;
      flair_url: string | null;
      flair_color: string | null;
      flair_bg_color: string | null;
    }[]
  | undefined
>();
expectTypeOf<
  NonNullable<TopicListEnvelope["users"]>[number]["id"]
>().toEqualTypeOf<number>();

const participant: TopicParticipant = {
  user_id: 1,
  extras: null,
  description: null,
  primary_group_id: null,
  flair_group_id: null,
};
const poster: TopicPoster = { ...participant, user };
const featured: TopicFeaturedUser[] = [
  poster,
  participant,
  { moreCount: "+2" },
];
expectTypeOf(featured).not.toBeAny();
expectTypeOf<TopicParticipant>().not.toHaveProperty("primary_group");
expectTypeOf<TopicPoster["primary_group"]>().toEqualTypeOf<
  (EmberObject & { id: number; name: string }) | undefined
>();

/* Navigation callbacks. */

// Existing callbacks use truthiness and may omit a custom URL.
addNavItem({
  name: "x",
  customFilter: () => user,
  customHref: () => undefined,
});
ExtraNavItem.create({
  name: "x",
  init(item, filterCategory, args) {
    expectTypeOf(item).toEqualTypeOf<ExtraNavItem>();
    expectTypeOf(filterCategory).toEqualTypeOf<Category | null | undefined>();
    expectTypeOf(args).toEqualTypeOf<NavItemOptions>();
  },
});
extraNavItemProperties(function (filterType, opts) {
  expectTypeOf(this).toEqualTypeOf<typeof NavItem>();
  expectTypeOf(filterType).toEqualTypeOf<string>();
  expectTypeOf(opts).toEqualTypeOf<NavItemOptions>();
  return { hasIcon: true };
});
customNavItemHref(function (item) {
  expectTypeOf(this).toEqualTypeOf<NavItem>();
  expectTypeOf(item).toEqualTypeOf<NavItem>();
  return undefined;
});
const descriptor: NavigationBarItem = {
  name: "x",
  customFilter(_category, args, router) {
    expectTypeOf(args).toEqualTypeOf<NavItemOptions>();
    expectTypeOf(router).toEqualTypeOf<RouterService>();
    return user;
  },
  init(item, _category, args, router) {
    expectTypeOf(item).toEqualTypeOf<ExtraNavItem>();
    expectTypeOf(args).toEqualTypeOf<NavItemOptions>();
    expectTypeOf(router).toEqualTypeOf<RouterService>();
  },
};
api.addNavigationBarItem(descriptor);
NavItem.buildList(category, options);

/* No any leaks. */

// Factory-returning services must not leak any through the navigation options.
expectTypeOf(options.siteSettings).not.toBeAny();
expectTypeOf(options.siteSettings?.top_menu).toEqualTypeOf<
  string | undefined
>();

type AnyKeys<T> = {
  [K in keyof T]-?: 0 extends 1 & T[K] ? K : never;
}[keyof T];
type AnyReturnKeys<T> = {
  [K in keyof T]-?: T[K] extends (...args: never) => infer R
    ? 0 extends 1 & R
      ? K
      : never
    : never;
}[keyof T];
type OwnAnyKeys<T, Base> = Exclude<
  AnyKeys<T> | AnyReturnKeys<T>,
  AnyKeys<Base> | AnyReturnKeys<Base>
>;
expectTypeOf<OwnAnyKeys<TopicList, EmberObject>>().toEqualTypeOf<never>();
expectTypeOf<OwnAnyKeys<NavItem, EmberObject>>().toEqualTypeOf<never>();
expectTypeOf<OwnAnyKeys<ExtraNavItem, EmberObject>>().toEqualTypeOf<never>();
expectTypeOf<OwnAnyKeys<CategoryList, EmberObject>>().toEqualTypeOf<never>();

/* ID-only parents. */

// Existing JS fixtures and factories use ID-only parent contexts.
CategoryList.categoriesFrom(store, {}, { id: 1 });
CategoryList.list(store, { id: 1 });
CategoryList.listForParent(store, { id: 1 });
CategoryList.create({ parentCategory: { id: 1 } });
