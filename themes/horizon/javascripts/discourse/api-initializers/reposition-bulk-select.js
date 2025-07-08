import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("0.8.0", (api) => {
  api.registerValueTransformer("bulk-select-in-nav-controls", () => {
    return true;
  });
});
