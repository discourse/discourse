import type { TrustedHTML } from "@ember/template";
import { expectTypeOf } from "expect-type";
import type Category from "discourse/models/category";
import type PendingPost from "discourse/models/pending-post";
import StoreService, { ModelFor } from "discourse/services/store";

declare const store: StoreService;
declare const pending: PendingPost;

expectTypeOf(pending.id).toEqualTypeOf<number>();
expectTypeOf(pending.created_at).toEqualTypeOf<string>();
expectTypeOf(pending.category_id).toEqualTypeOf<number | null>();
expectTypeOf(pending.topic_id).toEqualTypeOf<number | null>();
expectTypeOf(pending.created_by_id).toEqualTypeOf<number | null>();
expectTypeOf(pending.avatar_template).toEqualTypeOf<string | null>();
expectTypeOf(pending.username).toEqualTypeOf<string | null>();
expectTypeOf(pending.name).toEqualTypeOf<string | null>();
expectTypeOf(pending.topic_url).toEqualTypeOf<string | null>();
expectTypeOf(pending.raw_text).toEqualTypeOf<string | null>();
expectTypeOf(pending.title).toEqualTypeOf<string | null>();
expectTypeOf(pending.truncated).toEqualTypeOf<boolean>();
expectTypeOf(pending.expandedExcerpt).toEqualTypeOf<
  string | TrustedHTML | null
>();
expectTypeOf(pending.postUrl).toEqualTypeOf<string | null | undefined>();
pending.postUrl = "/t/x/1";
pending.postUrl = null;
pending.postUrl = undefined;
expectTypeOf(pending.userUrl).toEqualTypeOf<string>();
expectTypeOf(pending.category).toEqualTypeOf<Category | undefined>();

expectTypeOf<ModelFor<"pending-post">>().toEqualTypeOf<PendingPost>();
expectTypeOf(
  store.findAll("pending-post", { username: "x" })
).resolves.not.toBeAny();
