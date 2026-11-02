import { expectTypeOf } from "expect-type";
import TopicTimer from "discourse/models/topic-timer";

declare const timer: TopicTimer;

// The modal creates it with only a status type.
expectTypeOf(timer.status_type).toEqualTypeOf<string>();
expectTypeOf(timer.id).toEqualTypeOf<number | undefined>();
expectTypeOf(timer.execute_at).toEqualTypeOf<string | null | undefined>();
expectTypeOf(timer.duration_minutes).toEqualTypeOf<number | null | undefined>();
expectTypeOf(timer.based_on_last_post).toEqualTypeOf<boolean | undefined>();
expectTypeOf(timer.category_id).toEqualTypeOf<number | null | undefined>();
TopicTimer.create({ status_type: "close" });

// `POST /t/:id/timer` answers with this hash, not a serialized timer.
expectTypeOf(TopicTimer.update).returns.resolves.toEqualTypeOf<{
  success: "OK";
  execute_at: string | null;
  duration_minutes: number | null;
  based_on_last_post: boolean | null;
  category_id: number | null;
  closed: boolean;
}>();
TopicTimer.update(1, "2026-10-28 08:00", false, "close", null, null);
TopicTimer.update(1, 24, true, "open", 5, 60);
// Clearing a timer sends no time.
TopicTimer.update(1, null, false, "close", null, null);
