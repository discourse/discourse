import { expectTypeOf } from "expect-type";
import type PostActionType from "discourse/models/post-action-type";

declare const flag: PostActionType;

expectTypeOf(flag.id).toEqualTypeOf<number>();
expectTypeOf(flag.name).toEqualTypeOf<string>();
// A save callback always sets it, so it is never null in a payload.
expectTypeOf(flag.name_key).toEqualTypeOf<string>();
expectTypeOf(flag.description).toEqualTypeOf<string>();
expectTypeOf(flag.short_description).toEqualTypeOf<string>();
expectTypeOf(flag.applies_to).toEqualTypeOf<string[]>();
expectTypeOf(flag.require_message).toEqualTypeOf<boolean>();
expectTypeOf(flag.enabled).toEqualTypeOf<boolean>();
expectTypeOf(flag.is_flag).toEqualTypeOf<boolean>();
expectTypeOf(flag.is_used).toEqualTypeOf<boolean>();
expectTypeOf(flag.system).toEqualTypeOf<boolean>();
// The legacy flag-settings serializer omits these two.
expectTypeOf(flag.position).toEqualTypeOf<number | undefined>();
expectTypeOf(flag.auto_action_type).toEqualTypeOf<boolean | undefined>();
expectTypeOf(flag.isIllegal).toEqualTypeOf<boolean>();
expectTypeOf(flag.translatedDescription).toEqualTypeOf<string>();
