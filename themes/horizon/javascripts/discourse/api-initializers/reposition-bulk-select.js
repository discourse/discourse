import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  api.registerValueTransformer("bulk-select-in-nav-controls", () => {
    return true;
  });
});
