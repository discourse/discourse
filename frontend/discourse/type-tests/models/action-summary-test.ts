import { expectTypeOf } from "expect-type";
import ActionSummary from "discourse/models/action-summary";
import type Post from "discourse/models/post";
import PostActionType from "discourse/models/post-action-type";
import type RestModel from "discourse/models/rest";
import type Topic from "discourse/models/topic";

declare const post: Post;
declare const topic: Topic;
declare const summary: ActionSummary;

expectTypeOf(summary).toExtend<RestModel>();
expectTypeOf(summary.id).toEqualTypeOf<number>();
// Every construction path supplies a count: posts default it to 0 before
// `create`, and topic entries always send 0.
expectTypeOf(summary.count).toEqualTypeOf<number>();
// The server sends these only as `true`, but the client writes `false`.
expectTypeOf(summary.acted).toEqualTypeOf<boolean | undefined>();
expectTypeOf(summary.can_act).toEqualTypeOf<boolean | undefined>();
expectTypeOf(summary.can_undo).toEqualTypeOf<boolean | undefined>();
// Only topic-level entries carry `hidden`.
expectTypeOf(summary.hidden).toEqualTypeOf<boolean | undefined>();
// Client-assigned before `create`; the site lookup can miss.
expectTypeOf(summary.actionType).toEqualTypeOf<PostActionType | undefined>();
expectTypeOf(summary.post).toEqualTypeOf<Topic | undefined>();
expectTypeOf(summary.flagTopic).toEqualTypeOf<Topic | undefined>();
expectTypeOf(summary.canToggle).toEqualTypeOf<boolean | undefined>();

expectTypeOf(summary.toggle(post)).toEqualTypeOf<boolean>();
expectTypeOf(summary.undo(post)).resolves.toEqualTypeOf<{ acted: false }>();
expectTypeOf(summary.act(post)).resolves.toEqualTypeOf<
  { acted: true; remaining: number; max: number } | undefined
>();
// Either branch can run, so the result is the union of both.
expectTypeOf<
  Awaited<ReturnType<ActionSummary["togglePromise"]>>
>().toEqualTypeOf<
  { acted: false } | { acted: true; remaining: number; max: number } | undefined
>();
summary.act(post, {
  message: "x",
  isWarning: true,
  takeAction: false,
  queue_for_review: true,
});
// Topic flags pass the topic itself.
summary.act(topic, { message: "A topic flag" });
// @ts-expect-error act options are checked
summary.act(post, { isWarning: "yes" });
// The failure path passes the post through; the parameter stays optional.
summary.removeAction();
summary.removeAction(post);

// The shapes core passes to `create`.
ActionSummary.create({
  id: 2,
  count: 0,
  acted: true,
  can_undo: true,
  actionType: PostActionType.create({ id: 2 }),
});
ActionSummary.create({
  id: 4,
  count: 0,
  hidden: false,
  can_act: false,
  post: topic,
});
// @ts-expect-error count is a number
ActionSummary.create({ id: 2, count: "1" });
