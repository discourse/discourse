import { expectTypeOf } from "expect-type";
import type PublishedPage from "discourse/models/published-page";
import StoreService, { ModelFor } from "discourse/services/store";

declare const store: StoreService;
declare const page: PublishedPage;

expectTypeOf(page.id).toEqualTypeOf<number>();
expectTypeOf(page.slug).toEqualTypeOf<string>();
// A new page starts from the topic's properties, which can lack `public`.
expectTypeOf(page.public).toEqualTypeOf<boolean | undefined>();
expectTypeOf(page.url).toEqualTypeOf<string>();

expectTypeOf<ModelFor<"published-page">>().toEqualTypeOf<PublishedPage>();
expectTypeOf<ModelFor<"published_page">>().toEqualTypeOf<PublishedPage>();
expectTypeOf(
  store.createRecord("published_page", { id: 1, slug: "s", public: false })
).toEqualTypeOf<PublishedPage>();
expectTypeOf(
  store.find("published_page", 1)
).resolves.toEqualTypeOf<PublishedPage>();
