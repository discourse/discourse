import { apiInitializer } from "discourse/lib/api";
import SidebarHomeLogo from "../components/sidebar-home-logo";
import UserColorPaletteSelector from "../components/user-color-palette-selector";

export default apiInitializer((api) => {
  api.renderInOutlet("before-sidebar-sections", SidebarHomeLogo);
  api.renderInOutlet("sidebar-footer-actions", UserColorPaletteSelector);
});
