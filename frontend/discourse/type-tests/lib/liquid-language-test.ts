import { expectTypeOf } from "expect-type";
import type {
  LiquidCompletionMetadata,
  LiquidOptions,
} from "discourse/lib/liquid-language";

const options: LiquidOptions = {
  base: "html",
  scope: () => ({ articles: [{ title: "Example" }] }),
  tags: ["for"],
  filters: [],
  describe: (path, value, { variable }) => {
    expectTypeOf(path).toEqualTypeOf<readonly string[]>();
    expectTypeOf(value).toBeUnknown();
    expectTypeOf(variable).toBeBoolean();
    return {
      detail: path.join("."),
      info: "A sample value",
      section: { name: "Fields", rank: 2 },
      boost: 1,
    };
  },
};
void options;
expectTypeOf<LiquidCompletionMetadata>().not.toHaveProperty("label");
expectTypeOf<LiquidCompletionMetadata>().not.toHaveProperty("apply");
expectTypeOf<LiquidCompletionMetadata>().not.toHaveProperty("type");
