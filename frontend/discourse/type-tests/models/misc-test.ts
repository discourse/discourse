import type EmberObject from "@ember/object";
import { expectTypeOf } from "expect-type";
import type { HelperContext } from "discourse/lib/helpers";
import BadgeGrouping, {
  badgeGroupingDisplayName,
} from "discourse/models/badge-grouping";
import type Category from "discourse/models/category";
import type CategoryList from "discourse/models/category-list";
import FormTemplate from "discourse/models/form-template";
import LivePostCounts from "discourse/models/live-post-counts";
import LoginMethod, {
  clearAuthMethods,
  findAll,
} from "discourse/models/login-method";
import PermissionType, {
  buildPermissionDescription,
} from "discourse/models/permission-type";
import type RestModel from "discourse/models/rest";
import ReviewableHistory, {
  CLAIMED,
  UNCLAIMED,
} from "discourse/models/reviewable-history";
import Session from "discourse/models/session";
import StaticPage from "discourse/models/static-page";
import type TopicList from "discourse/models/topic-list";
import TrustLevel from "discourse/models/trust-level";
import type User from "discourse/models/user";
import type {
  default as StoreService,
  ModelFor,
} from "discourse/services/store";

declare const store: StoreService;
declare const category: Category;
declare const topicList: TopicList;
declare const categoryList: CategoryList;
declare const helperContext: HelperContext;

declare module "discourse/models/session" {
  interface SessionFields {
    type_test_plugin_flag?: boolean;
  }
}

declare module "discourse/models/login-method" {
  interface LoginMethodFields {
    type_test_plugin_flag?: boolean;
  }
}

declare module "discourse/models/permission-type" {
  interface PermissionTypeFields {
    type_test_plugin_flag?: boolean;
  }
}

declare module "discourse/models/badge-grouping" {
  interface BadgeGroupingFields {
    type_test_plugin_flag?: boolean;
  }
}

/* Session: client-only state, never a server payload. */

const session = Session.current();
expectTypeOf(session).toEqualTypeOf<Session>();
expectTypeOf(session).toExtend<RestModel>();
expectTypeOf(helperContext.session).toEqualTypeOf<Session>();
expectTypeOf(Session.resetCurrent()).toEqualTypeOf<undefined>();
expectTypeOf(session.requiresRefresh).toEqualTypeOf<boolean>();
expectTypeOf(session.hasFocus).toEqualTypeOf<boolean | null>();
// Screen tracking records numbers; the topic controller resets entries to null.
expectTypeOf(session.highestSeenByTopic[1]).toEqualTypeOf<
  number | null | undefined
>();
// Discovery caches the last list, which the categories page fills with a CategoryList.
expectTypeOf(session.topicList).toEqualTypeOf<
  TopicList | CategoryList | null | undefined
>();
session.set("topicList", topicList);
session.set("topicList", categoryList);
session.set("topicList", null);
// The meta tag can be missing, and a failed request clears the token to null.
expectTypeOf(Session.currentProp("csrfToken")).toEqualTypeOf<
  string | null | undefined
>();
Session.currentProp("csrfToken", "token");
// @ts-expect-error the token is a string
Session.currentProp("csrfToken", 1);
// Boot copies these from the page's data attributes.
expectTypeOf(session.userColorSchemeId).toEqualTypeOf<number | undefined>();
expectTypeOf(session.userDarkSchemeId).toEqualTypeOf<number | undefined>();
expectTypeOf(session.darkModeAvailable).toEqualTypeOf<boolean | undefined>();
expectTypeOf(session.highlightJsPath).toEqualTypeOf<string | undefined>();
// Menus cache their items under keys built at runtime.
Session.currentProp("user-menu-items:notifications", []);
expectTypeOf(session["user-menu-items:notifications"]).toEqualTypeOf<
  unknown[] | undefined
>();
expectTypeOf(Session.currentProp("runtime:cache")).toBeUnknown();
Session.currentProp("runtime:cache", { items: [] });
expectTypeOf(Session.createCurrent()).toEqualTypeOf<Session>();
expectTypeOf(Session.resetCurrent(null)).toEqualTypeOf<null>();
expectTypeOf(Session.resetCurrent(session)).toEqualTypeOf<Session>();
expectTypeOf(Session.currentProp("type_test_plugin_flag")).toEqualTypeOf<
  boolean | undefined
>();
expectTypeOf(session.bookmarksModel?.searchTerm).toEqualTypeOf<
  string | null | undefined
>();
session.highestSeenByTopic[1] = null;

/* TrustLevel: built by Site from `trust_levels`. */

const trustLevel = new TrustLevel(1, "basic");
expectTypeOf(trustLevel.id).toEqualTypeOf<number>();
expectTypeOf(trustLevel.name).toEqualTypeOf<string>();
expectTypeOf(trustLevel.detailedName).toEqualTypeOf<string>();
// @ts-expect-error ids are numbers
expectTypeOf(new TrustLevel("1", "basic")).toEqualTypeOf<TrustLevel>();

/* PermissionType: synthesized client-side from a permission number. */

expectTypeOf(PermissionType.FULL).toEqualTypeOf<number>();
expectTypeOf(PermissionType.CREATE_POST).toEqualTypeOf<number>();
expectTypeOf(PermissionType.READONLY).toEqualTypeOf<number>();
expectTypeOf(PermissionType.DESCRIPTION_KEYS[1]).toEqualTypeOf<
  string | undefined
>();
const permission = PermissionType.create({ id: PermissionType.FULL });
expectTypeOf(permission).toExtend<EmberObject>();
expectTypeOf(permission.id).toEqualTypeOf<number>();
expectTypeOf(permission.description).toEqualTypeOf<string>();
expectTypeOf(buildPermissionDescription(2)).toEqualTypeOf<string>();
expectTypeOf(category.availablePermissions).toEqualTypeOf<PermissionType[]>();
// @ts-expect-error permission ids are numbers
PermissionType.create({ id: "1" });
// The constants are writable statics.
PermissionType.FULL = 1;
PermissionType.DESCRIPTION_KEYS[99] = "custom";
expectTypeOf(
  PermissionType.create({ id: 1, type_test_plugin_flag: true })
    .type_test_plugin_flag
).toBeBoolean();

/* LoginMethod: Site's `auth_providers`. */

const methods = findAll();
expectTypeOf(methods).toEqualTypeOf<LoginMethod[]>();
clearAuthMethods();
const method = methods[0];
expectTypeOf(method).toExtend<EmberObject>();
expectTypeOf(method.name).toEqualTypeOf<string>();
expectTypeOf(method.can_connect).toEqualTypeOf<boolean>();
expectTypeOf(method.can_revoke).toEqualTypeOf<boolean>();
// Unset provider options serialize as null.
expectTypeOf(method.custom_url).toEqualTypeOf<string | null>();
expectTypeOf(method.frame_height).toEqualTypeOf<number | null>();
expectTypeOf(method.frame_width).toEqualTypeOf<number | null>();
expectTypeOf(method.icon_override).toEqualTypeOf<string | null>();
expectTypeOf(method.pretty_name_override).toEqualTypeOf<string | null>();
expectTypeOf(method.provider_url).toEqualTypeOf<string | null>();
expectTypeOf(method.title_override).toEqualTypeOf<string | null>();
// Set by findAll only.
expectTypeOf(method.isGoogle).toEqualTypeOf<boolean | undefined>();
expectTypeOf(method.isDiscourseID).toEqualTypeOf<boolean | undefined>();
expectTypeOf(method.title).toEqualTypeOf<string>();
expectTypeOf(method.icon).toEqualTypeOf<string>();
expectTypeOf(method.screenReaderTitle).toEqualTypeOf<string>();
expectTypeOf(method.prettyName).toEqualTypeOf<string>();
// A plugin hides an existing provider's connect button.
method.can_connect = false;
method.set("can_connect", false);
expectTypeOf<
  Awaited<ReturnType<LoginMethod["doLogin"]>>
>().toEqualTypeOf<void>();
method.doLogin();
method.doLogin({ signup: true });
method.doLogin({ reconnect: true });
method.doLogin({ signup: true, params: { origin: "/t/1" } });
// @ts-expect-error signup is a flag
method.doLogin({ signup: "yes" });
expectTypeOf<
  Awaited<ReturnType<typeof LoginMethod.buildPostForm>>
>().toEqualTypeOf<HTMLFormElement>();
LoginMethod.buildPostForm("/auth/github");
LoginMethod.buildPostForm("/auth/github", { origin: "/t/1" });
method.custom_url = null;
method.customLogin = () => {};
expectTypeOf(method.customLogin).toEqualTypeOf<() => void>();
method.doLogin({ params: { signup: true, attempt: 1, absent: null } });
expectTypeOf<LoginMethod["type_test_plugin_flag"]>().toEqualTypeOf<
  boolean | undefined
>();

/* LivePostCounts: `/about/live_post_counts.json`. */

declare const counts: Awaited<ReturnType<typeof LivePostCounts.find>>;
expectTypeOf(counts).toEqualTypeOf<LivePostCounts>();
expectTypeOf(counts.public_topic_count).toEqualTypeOf<number>();
expectTypeOf(counts.public_post_count).toEqualTypeOf<number>();

/* StaticPage: preloaded markup or `/:path.html`. */

StaticPage.find("faq");
declare const page: Awaited<ReturnType<typeof StaticPage.find>>;
expectTypeOf(page).toEqualTypeOf<StaticPage>();
expectTypeOf(page.path).toEqualTypeOf<string>();
expectTypeOf(page.html).toEqualTypeOf<string>();

/* BadgeGrouping: admin badge groupings. */

expectTypeOf<ModelFor<"badge-grouping">>().toEqualTypeOf<BadgeGrouping>();
const grouping = store.createRecord("badge-grouping", {
  editing: true,
  name: "Community",
});
expectTypeOf(grouping).toEqualTypeOf<BadgeGrouping>();
expectTypeOf(grouping.id).toEqualTypeOf<number>();
expectTypeOf(grouping.name).toEqualTypeOf<string>();
expectTypeOf(grouping.description).toEqualTypeOf<string | null>();
expectTypeOf(grouping.position).toEqualTypeOf<number>();
expectTypeOf(grouping.system).toEqualTypeOf<boolean>();
// The edit modal tracks which rows are open.
expectTypeOf(grouping.editing).toEqualTypeOf<boolean | undefined>();
expectTypeOf(grouping.displayName).toEqualTypeOf<string>();
expectTypeOf(grouping.i18nNameKey).toEqualTypeOf<string>();
expectTypeOf(badgeGroupingDisplayName("Community")).toEqualTypeOf<string>();
BadgeGrouping.create({ id: 1, name: "Community", description: null });
expectTypeOf<BadgeGrouping["type_test_plugin_flag"]>().toEqualTypeOf<
  boolean | undefined
>();
expectTypeOf<ModelFor<"BadgeGrouping">>().toEqualTypeOf<BadgeGrouping>();
expectTypeOf<ModelFor<"badge_grouping">>().toEqualTypeOf<BadgeGrouping>();

/* FormTemplate: the factories return plain JSON, not instances. */

expectTypeOf<Awaited<ReturnType<typeof FormTemplate.findAll>>>().toEqualTypeOf<
  { id: number; name: string; template: string }[]
>();
FormTemplate.findById(83);
expectTypeOf<
  Awaited<ReturnType<typeof FormTemplate.findById>>
>().toEqualTypeOf<{
  form_template: { id: number; name: string; template: string };
}>();

/* ReviewableHistory: side-loaded with reviewables. */

expectTypeOf(CLAIMED).toEqualTypeOf<3>();
expectTypeOf(UNCLAIMED).toEqualTypeOf<4>();
declare const history: ReviewableHistory;
expectTypeOf(history).toExtend<RestModel>();
expectTypeOf(history.id).toEqualTypeOf<number>();
expectTypeOf(history.reviewable_history_type).toEqualTypeOf<number>();
expectTypeOf(history.status).toEqualTypeOf<number>();
expectTypeOf(history.created_at).toEqualTypeOf<string>();
// Hydration sets a creator missing from the side-load to null.
expectTypeOf(history.created_by).toEqualTypeOf<User | null | undefined>();
expectTypeOf(history.created_by_id).toEqualTypeOf<number | undefined>();
