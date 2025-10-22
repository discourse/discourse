import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  api.registerValueTransformer(
    "hamburger-dropdown-click-outside-exceptions",
    ({ value }) => {
      return [...value, ".topic-drafts-menu-content"];
    }
  );
});
