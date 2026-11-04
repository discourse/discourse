import type EmberObject from "@ember/object";
import { expectTypeOf } from "expect-type";
import AssociatedGroup from "discourse/models/associated-group";
import type Category from "discourse/models/category";
import Draft from "discourse/models/draft";
import type GroupHistory from "discourse/models/group-history";
import type RestModel from "discourse/models/rest";
import type { TopicBasicUser } from "discourse/models/topic";
import UserAction from "discourse/models/user-action";
import type UserActionGroup from "discourse/models/user-action-group";
import UserActionStat from "discourse/models/user-action-stat";
import type UserPostsStream from "discourse/models/user-posts-stream";
import type UserStream from "discourse/models/user-stream";

/* UserAction: `/user_actions.json` rows, or posts from `/posts/:username/deleted`. */

declare const action: UserAction;
expectTypeOf(action).toExtend<RestModel>();
// The deleted-posts feed finds no reply action for most posts.
expectTypeOf(action.action_type).toEqualTypeOf<number | null>();
expectTypeOf(action.created_at).toEqualTypeOf<string>();
expectTypeOf(action.topic_id).toEqualTypeOf<number>();
expectTypeOf(action.post_id).toEqualTypeOf<number | null>();
expectTypeOf(action.post_number).toEqualTypeOf<number | null>();
expectTypeOf(action.avatar_template).toEqualTypeOf<string>();
expectTypeOf(action.title).toEqualTypeOf<string | null>();
// Sent only when names are enabled.
expectTypeOf(action.name).toEqualTypeOf<string | null | undefined>();
// Collapsing a like or edit swaps in the acting user, who can be absent.
expectTypeOf(action.username).toEqualTypeOf<string | null>();
expectTypeOf(action.acting_username).toEqualTypeOf<string | null | undefined>();
expectTypeOf(action.acting_avatar_template).toEqualTypeOf<string | undefined>();
expectTypeOf(action.target_username).toEqualTypeOf<string | null | undefined>();
expectTypeOf(action.category_id).toEqualTypeOf<number | null>();
expectTypeOf(action.deleted).toEqualTypeOf<boolean>();
// Topic actions have no post row, so its columns come back null.
expectTypeOf(action.hidden).toEqualTypeOf<boolean | null>();
expectTypeOf(action.post_type).toEqualTypeOf<number | null | undefined>();
// Sent only for replies.
expectTypeOf(action.reply_to_post_number).toEqualTypeOf<
  number | null | undefined
>();
// Omitted when the viewer can't see the post behind the excerpt.
expectTypeOf(action.excerpt).toEqualTypeOf<string | null | undefined>();
expectTypeOf(action.truncated).toEqualTypeOf<true | undefined>();
// The deleted-posts feed only.
expectTypeOf(action.deleted_at).toEqualTypeOf<string | null | undefined>();
expectTypeOf(action.deleted_by).toEqualTypeOf<TopicBasicUser | undefined>();

expectTypeOf(action.presentName).toEqualTypeOf<string | null | undefined>();
expectTypeOf(action.isPM).toEqualTypeOf<boolean>();
expectTypeOf(action.postReplyType).toEqualTypeOf<boolean>();
expectTypeOf(action.descriptionKey).toEqualTypeOf<string | undefined>();
expectTypeOf(action.postUrl).toEqualTypeOf<string>();
expectTypeOf(action.userUrl).toEqualTypeOf<string>();
expectTypeOf(action.titleHtml).toEqualTypeOf<string | null>();
// Sent only when the topic has a title.
expectTypeOf(action.slug).toEqualTypeOf<string | null | undefined>();
expectTypeOf(action.action_code).toEqualTypeOf<string | null | undefined>();
expectTypeOf(action.edit_reason).toEqualTypeOf<string | null | undefined>();
expectTypeOf(action.category).toEqualTypeOf<Category | undefined>();
expectTypeOf(action.children).toEqualTypeOf<UserActionGroup[]>();
action.addChild(action);
action.switchToActing();

expectTypeOf(UserAction.TYPES.likes_given).toEqualTypeOf<number>();
expectTypeOf(UserAction.TYPES.messages_received).toEqualTypeOf<number>();
expectTypeOf(UserAction.TO_COLLAPSE).toEqualTypeOf<number[]>();
expectTypeOf(UserAction.collapseStream([action])).toEqualTypeOf<UserAction[]>();

declare const group: UserActionGroup;
expectTypeOf(group).toExtend<EmberObject>();
expectTypeOf(group.icon).toEqualTypeOf<string>();
expectTypeOf(group.items).toEqualTypeOf<UserAction[] | undefined>();
expectTypeOf(group.push(action)).toEqualTypeOf<number>();

/* UserActionStat: built client-side to group response counts. */

const stat = UserActionStat.create({ count: 0, action_type: 6 });
expectTypeOf(stat.count).toEqualTypeOf<number>();
expectTypeOf(stat.action_type).toEqualTypeOf<number>();
expectTypeOf(stat.description).toEqualTypeOf<string>();
expectTypeOf(stat.isPM).toEqualTypeOf<boolean>();
expectTypeOf(stat.isResponse).toEqualTypeOf<boolean>();

/* Streams. */

declare const stream: UserStream;
expectTypeOf(stream.content).toEqualTypeOf<UserAction[]>();
expectTypeOf(stream.loaded).toEqualTypeOf<boolean>();
expectTypeOf(stream.loading).toEqualTypeOf<boolean>();
expectTypeOf(stream.itemsLoaded).toEqualTypeOf<number>();
expectTypeOf(stream.nextFindUrl).toEqualTypeOf<string>();
expectTypeOf(stream.canLoadMore).toEqualTypeOf<boolean>();
expectTypeOf(stream.noContent).toEqualTypeOf<boolean>();
expectTypeOf(stream.findItems()).resolves.toEqualTypeOf<void>();
// Activity routes pass a numeric action type or none, and an optional acting user.
expectTypeOf(
  stream.filterBy({ filter: 1, actingUsername: "sam" })
).resolves.toEqualTypeOf<void>();
stream.filterBy({ filter: undefined, actingUsername: undefined });
stream.filterBy({ filter: null, actingUsername: null });
stream.filterBy({});
stream.remove(action);

declare const postsStream: UserPostsStream;
expectTypeOf(postsStream).toExtend<EmberObject>();
expectTypeOf(postsStream.content).toEqualTypeOf<UserAction[]>();
expectTypeOf(postsStream.canLoadMore).toEqualTypeOf<boolean>();
expectTypeOf(postsStream.url).toEqualTypeOf<string>();
expectTypeOf(
  postsStream.filterBy({ filter: "deleted" })
).resolves.toEqualTypeOf<void>();
postsStream.filterBy({ filter: "pending" });

/* GroupHistory: entries from the group logs. */

declare const history: GroupHistory;
expectTypeOf(history.action).toEqualTypeOf<string>();
expectTypeOf(history.subject).toEqualTypeOf<string | null>();
expectTypeOf(history.prev_value).toEqualTypeOf<string | null>();
expectTypeOf(history.new_value).toEqualTypeOf<string | null>();
expectTypeOf(history.created_at).toEqualTypeOf<string>();
expectTypeOf(history.acting_user).toEqualTypeOf<TopicBasicUser | null>();
expectTypeOf(history.target_user).toEqualTypeOf<TopicBasicUser | null>();
expectTypeOf(history.actionTitle).toEqualTypeOf<string>();

/* AssociatedGroup: groups from authentication providers. */

expectTypeOf(AssociatedGroup.list()).resolves.toEqualTypeOf<
  AssociatedGroup[] | undefined
>();
declare const associated: AssociatedGroup;
expectTypeOf(associated.id).toEqualTypeOf<number>();
expectTypeOf(associated.name).toEqualTypeOf<string>();
expectTypeOf(associated.provider_name).toEqualTypeOf<string>();
expectTypeOf(associated.label).toEqualTypeOf<string>();

/* Draft: static helpers over the drafts endpoints. */

// `draft` is the saved JSON string, or null when there is none or it is stale.
expectTypeOf(Draft.get("new_topic")).resolves.toEqualTypeOf<{
  draft: string | null;
  draft_sequence: number;
}>();
expectTypeOf(
  Draft.save("new_topic", 0, { reply: "x" }, "client-1")
).resolves.toExtend<{ success: "OK"; draft_sequence: number }>();
Draft.save("new_topic", 0, "{}", "client-1", { forceSave: true });
Draft.clear("new_topic", 3);
Draft.bulkClear([{ draft_key: "new_topic", sequence: 3 }]);
expectTypeOf(Draft.getLocal("new_topic", "{}")).toEqualTypeOf<string>();
expectTypeOf(Draft.getLocal("new_topic", null)).toEqualTypeOf<null>();
expectTypeOf(
  Draft.saveBeacon("new_topic", 0, { reply: "x" }, "client-1", "token")
).toEqualTypeOf<void>();
