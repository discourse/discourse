import { apiInitializer } from "discourse/lib/api";
import SidebarHomeLogo from "../components/sidebar-home-logo";
import UserColorPaletteSelector from "../components/user-color-palette-selector";

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  if (siteSettings.enable_horizon_updates) {
    api.renderInOutlet("before-sidebar-sections", SidebarHomeLogo);
  }

  api.renderInOutlet("sidebar-footer-actions", UserColorPaletteSelector);
});
