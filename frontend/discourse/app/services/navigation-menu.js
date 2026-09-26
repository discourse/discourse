import Service, { service } from "discourse/lib/service";
import { disableImplicitInjections } from "discourse/lib/disable-implicit-injections";
import SiteService from "discourse/services/site";
import SiteSettingsService from "discourse/services/site-settings";

@disableImplicitInjections
export default class NavigationMenu extends Service {
  @service(() => SiteService) site;
  @service(() => SiteSettingsService) siteSettings;

  get isHeaderDropdownMode() {
    return this.siteSettings.navigation_menu === "header dropdown";
  }

  get isDesktopDropdownMode() {
    return this.site.desktopView && this.isHeaderDropdownMode;
  }

  get displayMode() {
    return this.isDesktopDropdownMode ? "header_dropdown" : "sidebar";
  }
}
