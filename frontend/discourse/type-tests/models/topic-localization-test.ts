import { expectTypeOf } from "expect-type";
import TopicLocalization from "discourse/models/topic-localization";

expectTypeOf(TopicLocalization.fetch).returns.resolves.toEqualTypeOf<{
  id: number;
  topic_id: number;
  locale: string;
  title: string;
  fancy_title: string;
}>();
expectTypeOf(TopicLocalization.updateLocale).returns.resolves.toEqualTypeOf<{
  locale: string | null;
}>();
expectTypeOf(TopicLocalization.createOrUpdate).returns.resolves.toEqualTypeOf<{
  success: "OK";
}>();
expectTypeOf(TopicLocalization.destroy).returns.resolves.toEqualTypeOf<void>();

TopicLocalization.updateLocale(1, undefined);
TopicLocalization.createOrUpdate(1, "ja", "title");
TopicLocalization.destroy(1, "ja");
