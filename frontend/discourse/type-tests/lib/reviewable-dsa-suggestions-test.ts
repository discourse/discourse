import { expectTypeOf } from "expect-type";
import type { PluginApi } from "discourse/lib/plugin-api";
import type {
  ReviewableDsaFieldOutcome,
  ReviewableDsaSuggestionProvider,
  ReviewableDsaSuggestions,
} from "discourse/services/reviewable-dsa-suggestions";

expectTypeOf<PluginApi["registerReviewableDsaSuggestionProvider"]>()
  .parameter(0)
  .toEqualTypeOf<ReviewableDsaSuggestionProvider>();

expectTypeOf<
  ReviewableDsaSuggestionProvider["suggest"]
>().parameters.toEqualTypeOf<[number]>();
expectTypeOf<
  ReviewableDsaSuggestionProvider["suggest"]
>().returns.resolves.toEqualTypeOf<ReviewableDsaSuggestions>();
expectTypeOf<{
  value: string;
  label: string;
  errorLabel: string;
}>().not.toMatchTypeOf<ReviewableDsaFieldOutcome>();
