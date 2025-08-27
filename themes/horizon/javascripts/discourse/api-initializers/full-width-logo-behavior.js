import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  document.body.classList.add("full-width-enabled");

  // When the sidebar is visible, force the HomeLogo to be in an 'un-minimized' state.
  api.registerValueTransformer?.(
    "home-logo-minimized",
    ({ value, context }) => {
      if (value && context.showSidebar) {
        return false;
      }
      return value;
    }
  );
});
