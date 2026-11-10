import type EmberObject from "@ember/object";
import { expectTypeOf } from "expect-type";
import type Category from "discourse/models/category";
import Group, {
  type GroupFields,
  type GroupMembersResponse,
  type GroupRequestersResponse,
} from "discourse/models/group";
import type GroupHistory from "discourse/models/group-history";
import type RestModel from "discourse/models/rest";
import type Topic from "discourse/models/topic";
import User, { UserGroup } from "discourse/models/user";
import type {
  default as StoreService,
  ModelCreateAttrsFor,
  ModelFor,
} from "discourse/services/store";

declare const store: StoreService;
declare const group: Group;
declare const user: User;

expectTypeOf(group).toExtend<RestModel>();
expectTypeOf(group).not.toBeAny();
expectTypeOf<ModelFor<"group">>().toEqualTypeOf<Group>();
expectTypeOf(store.find("group", "staff")).resolves.toEqualTypeOf<Group>();
expectTypeOf(
  store.createRecord("group", { name: "staff" })
).toEqualTypeOf<Group>();

/* Construction. */

// The new-group route starts with no id or name; `create` assigns the id.
expectTypeOf(
  Group.create({ automatic: false, visibility_level: 0, can_admin_group: true })
).toEqualTypeOf<Group>();
// @ts-expect-error names are strings
Group.create({ name: 1 });
expectTypeOf(group.id).toEqualTypeOf<number | undefined>();
expectTypeOf(group.name).toEqualTypeOf<string | undefined>();

/* Serializer fields. */

expectTypeOf(group.automatic).toEqualTypeOf<boolean | undefined>();
expectTypeOf(group.visibility_level).toEqualTypeOf<number | undefined>();
// The alias-level columns are nullable.
expectTypeOf(group.mentionable_level).toEqualTypeOf<
  number | null | undefined
>();
expectTypeOf(group.messageable_level).toEqualTypeOf<
  number | null | undefined
>();
expectTypeOf(group.title).toEqualTypeOf<string | null | undefined>();
expectTypeOf(group.full_name).toEqualTypeOf<string | null | undefined>();
expectTypeOf(group.flair_url).toEqualTypeOf<string | null | undefined>();
expectTypeOf(group.flair_bg_color).toEqualTypeOf<string | null | undefined>();
expectTypeOf(group.bio_cooked).toEqualTypeOf<string | null | undefined>();
expectTypeOf(group.grant_trust_level).toEqualTypeOf<
  number | null | undefined
>();
expectTypeOf(group.can_see_members).toEqualTypeOf<boolean | undefined>();
expectTypeOf(group.is_group_user).toEqualTypeOf<boolean | undefined>();
// Admin-only SMTP settings.
expectTypeOf(group.smtp_port).toEqualTypeOf<number | null | undefined>();
expectTypeOf(group.watching_category_ids).toEqualTypeOf<number[] | undefined>();
// Profiles attach the viewer's membership by index.
expectTypeOf<
  NonNullable<Group["group_user"]>["notification_level"]
>().toEqualTypeOf<number>();

/* Client state. */

expectTypeOf(group.user_count).toEqualTypeOf<number>();
expectTypeOf(group.request_count).toEqualTypeOf<number>();
expectTypeOf(group.limit).toEqualTypeOf<number | null>();
expectTypeOf(group.requestersOffset).toEqualTypeOf<number | null>();
expectTypeOf(group.members).toEqualTypeOf<User[]>();
expectTypeOf(group.requesters).toEqualTypeOf<User[]>();

/* Derived state. */

expectTypeOf(group.canEveryoneMention).toEqualTypeOf<boolean>();
expectTypeOf(group.emailDomains).toEqualTypeOf<string>();
expectTypeOf(group.associatedGroupIds).toEqualTypeOf<number[]>();
expectTypeOf(group.type).toEqualTypeOf<"automatic" | "custom">();
expectTypeOf(group.displayName).toEqualTypeOf<string | undefined>();
expectTypeOf(group.flairBackgroundHexColor).toEqualTypeOf<string | null>();
expectTypeOf(group.isPrivate).toEqualTypeOf<boolean>();
expectTypeOf(group.watchingCategories).toEqualTypeOf<Category[]>();
group.mutedCategories = [];

/* Members. */

expectTypeOf(
  group.reloadMembers({ order: "name", asc: true, filter: "sam" }, true)
).resolves.toEqualTypeOf<void>();
group.reloadMembers();
group.reloadMembers({ limit: 10 }, true);
expectTypeOf(
  group.findRequesters({ order: "", asc: false, filter: null }, true)
).resolves.toEqualTypeOf<void>();
group.addMembers("sam,jane", true, false, "sam@example.com");
group.addMembers("sam");
group.addOwners("sam", true, true);
group.removeMember(user, { order: "name" });
group.removeOwner(user);
expectTypeOf(group.join()).resolves.toEqualTypeOf<void>();
expectTypeOf(group.leave()).resolves.toEqualTypeOf<void>();

/* Persistence: these replace the inherited RestModel operations. */

expectTypeOf(group.asJSON()).toExtend<{
  name: string | undefined;
  primary_group: boolean;
}>();
group.create();
group.save();
group.save({ update_existing_users: true });
group.destroy();

/* Activity. */

expectTypeOf(group.findLogs()).resolves.toExtend<{
  logs: GroupHistory[];
  all_loaded: boolean;
}>();
group.findLogs(2, { action: "change_group_setting", acting_user: "sam" });
expectTypeOf(
  group.findPosts({ type: "mentions", categoryId: 3, before: undefined })
).resolves.toExtend<{ user: User; topic: Topic; category?: Category }[]>();
group.findPosts();
group.setNotification(3, 1);
group.requestMembership("Please add me");

/* Statics. */

expectTypeOf(
  Group.findAll({ term: "sta", ignore_automatic: true })
).resolves.toEqualTypeOf<Group[]>();
Group.findAll();
Group.loadMembers("staff", { offset: 0, requesters: true });
Group.mentionable("staff");
Group.messageable("staff");
Group.checkName("staff");

/* Consumers: users manage hydrated groups without casts. */

expectTypeOf(user.canManageGroup(group)).toEqualTypeOf<boolean | undefined>();

/* Base compatibility: the async overrides stay assignable to RestModel. */

expectTypeOf(group).toExtend<EmberObject>();
expectTypeOf<typeof Group>().toExtend<typeof RestModel>();
expectTypeOf<ModelFor<"Group">>().toEqualTypeOf<Group>();
expectTypeOf<ModelCreateAttrsFor<"group">["name"]>().toEqualTypeOf<
  string | undefined
>();
expectTypeOf(group.save()).resolves.toEqualTypeOf<
  { success: string } | undefined
>();
expectTypeOf(group.destroy()).resolves.toEqualTypeOf<
  { success: string } | undefined
>();
expectTypeOf(group.create()).resolves.toExtend<{ id: number; name: string }>();

/* Member responses: requester lists have no owners. */

expectTypeOf(
  Group.loadMembers("staff")
).resolves.toEqualTypeOf<GroupMembersResponse>();
expectTypeOf(
  Group.loadMembers("staff", { requesters: true })
).resolves.toEqualTypeOf<GroupRequestersResponse>();
expectTypeOf<keyof GroupRequestersResponse>().toEqualTypeOf<
  "members" | "meta"
>();
expectTypeOf<
  GroupRequestersResponse["members"][number]["reason"]
>().toEqualTypeOf<string | null>();

/* Nullable show fields and boundaries. */

expectTypeOf<GroupFields["smtp_enabled"]>().toEqualTypeOf<
  boolean | null | undefined
>();
expectTypeOf<GroupFields["display_name"]>().toEqualTypeOf<
  string | null | undefined
>();
expectTypeOf<GroupFields["smtp_updated_at"]>().toEqualTypeOf<
  string | null | undefined
>();
expectTypeOf<GroupFields["smtp_updated_by"]>().toBeNullable();
expectTypeOf<GroupFields>().not.toHaveProperty("displayName");
// Plugin serializer fields are added by augmentation, not by core.
expectTypeOf<GroupFields>().not.toHaveProperty("assignment_count");

/* Current-user memberships are plain entries with identity. */

expectTypeOf<UserGroup["id"]>().toEqualTypeOf<number>();
expectTypeOf<UserGroup["name"]>().toEqualTypeOf<string>();
expectTypeOf<UserGroup>().not.toExtend<Group>();

/* Saving: editors send tag records or names, and asJSON keeps its sentinels. */

Group.create({ watching_tags: ["a", { id: 1, name: "b", slug: "b" }] });
group.addMembers(["sam", "jane"], false, true, ["sam@example.com"]);
expectTypeOf(group.asJSON().associated_group_ids).toEqualTypeOf<
  (number | null)[] | undefined
>();
expectTypeOf(group.asJSON().watching_tags).toEqualTypeOf<
  string[] | undefined
>();
