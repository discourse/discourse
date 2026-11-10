import { expectTypeOf } from "expect-type";
import { mergeSortedLists, toAsciiPrintable } from "discourse/lib/utilities";

// Callers merge lists of different kinds, such as notifications with topics.
const notifications = [{ created_at: "2026-01-01" }];
const topics = [{ bumped_at: "2026-01-02" }];
expectTypeOf(
  mergeSortedLists(
    notifications,
    topics,
    (notification, topic) =>
      new Date(topic.bumped_at) > new Date(notification.created_at)
  )
).toEqualTypeOf<({ created_at: string } | { bumped_at: string })[]>();

// A fallback replaces `undefined` in the result.
expectTypeOf(toAsciiPrintable("text")).toEqualTypeOf<string | undefined>();
expectTypeOf(toAsciiPrintable("text", "discourse")).toEqualTypeOf<string>();
expectTypeOf(toAsciiPrintable("text", null)).toEqualTypeOf<string | null>();
