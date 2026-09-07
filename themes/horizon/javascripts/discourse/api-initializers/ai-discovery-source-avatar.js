import { apiInitializer } from "discourse/lib/api";

// Horizon's related discussions list is roomy enough for the author's face.
export default apiInitializer((api) => {
  api.registerValueTransformer("ai-discovery-source-avatar", () => true);
});
