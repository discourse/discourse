import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  api.registerValueTransformer(
    "search-result-entry-class",
    ({ value, context }) => {
      if (context.post.generatedByAi) {
        value.push("ai-result");
      }
      return value;
    }
  );
});
