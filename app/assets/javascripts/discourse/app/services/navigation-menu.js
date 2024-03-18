import Service, { service } from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

@disableImplicitInjections
export default class NavigationMenu extends Service {
  @service site;
  @service siteSettings;

  get isDesktopDropdownMode() {
    const headerDropdownMode =
      this.siteSettings.navigation_menu === "header dropdown";

    return this.site.desktopView && headerDropdownMode;
  }
}
