import { expectTypeOf } from "expect-type";
import { withPluginApi } from "discourse/lib/plugin-api";
import {
  applyMutableValueTransformer,
  applyValueTransformer,
  type ValueTransformerFor,
} from "discourse/lib/transformer";
import type Category from "discourse/models/category";
import type Topic from "discourse/models/topic";
import type UserDraft from "discourse/models/user-draft";

type PreferencesPage =
  | "account"
  | "emails"
  | "interface"
  | "navigation-menu"
  | "notifications"
  | "profile"
  | "tags"
  | "tracking"
  | "users";

declare const topic: Topic;
declare const category: Category;
declare const draft: UserDraft;

const apply = applyValueTransformer;
const itemContext = { topic, index: 0, listContext: "discovery", category };
const logoContext = {
  topicInfo: topic,
  sidebarEnabled: true,
  showSidebar: false,
};

/* topic-list-item-class */
expectTypeOf(
  apply("topic-list-item-class", [] as string[], itemContext)
).toEqualTypeOf<string[]>();
// @ts-expect-error the value is a list of class names
apply("topic-list-item-class", "pinned", itemContext);
// @ts-expect-error the topic is required
apply("topic-list-item-class", [] as string[], { index: 0 });

/* home-logo-minimized */
expectTypeOf(
  apply("home-logo-minimized", false, logoContext)
).toEqualTypeOf<boolean>();
// @ts-expect-error the value is a boolean
apply("home-logo-minimized", "yes", logoContext);

/* search-menu-search-shortcuts-enabled */
expectTypeOf(
  apply("search-menu-search-shortcuts-enabled", true, { location: "header" })
).toEqualTypeOf<boolean>();
expectTypeOf(
  apply("search-menu-search-shortcuts-enabled", true, { location: undefined })
).toEqualTypeOf<boolean>();
// @ts-expect-error the context carries the location
apply("search-menu-search-shortcuts-enabled", true);

/* preferences-save-attributes */
expectTypeOf(
  apply("preferences-save-attributes", ["name"], { page: "account" })
).toEqualTypeOf<string[]>();
// @ts-expect-error pages are the preferences pages
apply("preferences-save-attributes", ["name"], { page: "billing" });

/* draft-icon */
expectTypeOf(apply("draft-icon", "reply", { draft })).toEqualTypeOf<string>();
// @ts-expect-error the context carries the draft
apply("draft-icon", "reply", {});

/* Registrants see each hook's contract */
withPluginApi((api) => {
  api.registerValueTransformer(
    "topic-list-item-class",
    ({ value, context }) => {
      expectTypeOf(value).toEqualTypeOf<string[]>();
      expectTypeOf(context.topic).toEqualTypeOf<Topic>();
      expectTypeOf(context.index).toEqualTypeOf<number | undefined>();
      expectTypeOf(context.listContext).toEqualTypeOf<string | undefined>();
      expectTypeOf(context.category).toEqualTypeOf<
        Category | null | undefined
      >();
      return value;
    }
  );
  api.registerValueTransformer("home-logo-minimized", ({ value, context }) => {
    expectTypeOf(context.topicInfo).toEqualTypeOf<Topic | null>();
    expectTypeOf(context.sidebarEnabled).toEqualTypeOf<boolean>();
    expectTypeOf(context.showSidebar).toEqualTypeOf<boolean>();
    return value;
  });
  api.registerValueTransformer(
    "search-menu-search-shortcuts-enabled",
    ({ context }) => {
      expectTypeOf(context.location).toEqualTypeOf<string | undefined>();
      return false;
    }
  );
  api.registerValueTransformer(
    "preferences-save-attributes",
    ({ value, context }) => {
      expectTypeOf(context.page).toEqualTypeOf<PreferencesPage>();
      return [...value, "custom_fields"];
    }
  );
  api.registerValueTransformer("draft-icon", ({ context }) => {
    expectTypeOf(context.draft).toEqualTypeOf<UserDraft>();
    return "robot";
  });

  // @ts-expect-error these hooks are immutable, so the callback must return the value
  api.registerValueTransformer("topic-list-item-class", ({ value }) => {
    value.push("x");
  });
  // @ts-expect-error the icon is a string
  api.registerValueTransformer("draft-icon", () => 1);
});

/* Every seeded hook resolves to a typed callback, not the generic fallback */
expectTypeOf<
  ValueTransformerFor<"topic-list-item-class">
>().returns.toEqualTypeOf<string[]>();
expectTypeOf<
  ValueTransformerFor<"home-logo-minimized">
>().returns.toEqualTypeOf<boolean>();
expectTypeOf<
  ValueTransformerFor<"search-menu-search-shortcuts-enabled">
>().returns.toEqualTypeOf<boolean>();
expectTypeOf<
  ValueTransformerFor<"preferences-save-attributes">
>().returns.toEqualTypeOf<string[]>();
expectTypeOf<
  ValueTransformerFor<"draft-icon">
>().returns.toEqualTypeOf<string>();

/* Optional context keys and the immutable contract */
const applyMut = applyMutableValueTransformer;
expectTypeOf(
  apply("topic-list-item-class", [] as string[], { topic })
).toEqualTypeOf<string[]>();
expectTypeOf(
  apply("topic-list-item-class", [] as string[], {
    topic,
    index: undefined,
    listContext: undefined,
    category: null,
  })
).toEqualTypeOf<string[]>();
expectTypeOf(
  apply("search-menu-search-shortcuts-enabled", true, {})
).toEqualTypeOf<boolean>();
// @ts-expect-error immutable hook through the mutable apply
applyMut("topic-list-item-class", [] as string[], { topic });
// @ts-expect-error immutable hook through the mutable apply
applyMut("home-logo-minimized", false, logoContext);
// @ts-expect-error immutable hook through the mutable apply
applyMut("search-menu-search-shortcuts-enabled", true, {});
// @ts-expect-error immutable hook through the mutable apply
applyMut("preferences-save-attributes", [] as string[], { page: "account" });
// @ts-expect-error immutable hook through the mutable apply
applyMut("draft-icon", "reply", { draft });
