import { apiInitializer } from "discourse/lib/api";
import ExperimentalScreen from "../components/experimental-screen";
import UserColorPaletteSelector from "../components/user-color-palette-selector";

export default apiInitializer("1.8.0", (api) => {
  api.renderInOutlet("above-main-container", ExperimentalScreen);
  api.renderInOutlet("sidebar-footer-actions", UserColorPaletteSelector);

  api.registerValueTransformer("site-setting-enable-welcome-banner", () => {
    return settings.enable_welcome_banner;
  });

  api.registerValueTransformer("site-setting-search-experience", () => {
    return settings.search_experience;
  });
});
