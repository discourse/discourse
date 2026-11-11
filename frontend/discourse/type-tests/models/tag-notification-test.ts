import { expectTypeOf } from "expect-type";
import RestCompatModel from "discourse/data/rest-compat";
import TagNotification, {
  type TagNotificationFields,
} from "discourse/models/tag-notification";
import type {
  default as StoreService,
  ModelFor,
} from "discourse/services/store";

declare const store: StoreService;
declare const tagNotification: TagNotification;

/** The `tag_notification` hash the tag notifications endpoint renders. */
interface ExpectedTagNotificationFields {
  id: number;
  name: string;
  notification_level: number;
}

declare module "discourse/models/tag-notification" {
  interface TagNotificationFields {
    type_test_plugin_flag?: boolean;
  }
}

expectTypeOf(tagNotification).toExtend<RestCompatModel>();
expectTypeOf(tagNotification).not.toBeAny();
expectTypeOf<ModelFor<"tag-notification">>().toEqualTypeOf<TagNotification>();
expectTypeOf<ModelFor<"tagNotification">>().toEqualTypeOf<TagNotification>();
expectTypeOf<ModelFor<"tag_notification">>().toEqualTypeOf<TagNotification>();
expectTypeOf(
  store.find("tagNotification", 1)
).resolves.toEqualTypeOf<TagNotification>();

/* Fields. */

expectTypeOf<
  Omit<TagNotificationFields, "type_test_plugin_flag">
>().toEqualTypeOf<ExpectedTagNotificationFields>();
expectTypeOf<
  Pick<TagNotification, keyof ExpectedTagNotificationFields>
>().toEqualTypeOf<ExpectedTagNotificationFields>();
expectTypeOf(tagNotification.type_test_plugin_flag).toEqualTypeOf<
  boolean | undefined
>();
tagNotification.notification_level = 3;
// @ts-expect-error notification levels are numbers
tagNotification.notification_level = "watching";

/* Updates address the record by tag name. */

expectTypeOf(tagNotification.primaryKey).toEqualTypeOf<string>();
expectTypeOf(tagNotification.update({ notification_level: 1 })).not.toBeAny();
