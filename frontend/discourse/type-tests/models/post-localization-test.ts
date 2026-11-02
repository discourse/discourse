import { expectTypeOf } from "expect-type";
import PostLocalization from "discourse/models/post-localization";

expectTypeOf(PostLocalization.find).returns.resolves.toEqualTypeOf<{
  post_localizations: {
    id: number;
    post_id: number;
    post_version: number;
    locale: string;
    raw: string;
    topic_localization?: {
      id: number;
      topic_id: number;
      locale: string;
      title: string;
      fancy_title: string;
    };
  }[];
}>();
expectTypeOf(PostLocalization.updateLocale).returns.resolves.toEqualTypeOf<{
  locale: string | null;
}>();
expectTypeOf(PostLocalization.createOrUpdate).returns.resolves.toEqualTypeOf<{
  success: "OK";
}>();
expectTypeOf(PostLocalization.destroy).returns.resolves.toEqualTypeOf<void>();

PostLocalization.updateLocale(1, null);
PostLocalization.createOrUpdate(1, "ja", "raw");
PostLocalization.destroy(1, "ja");
