import Service, { service } from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

@disableImplicitInjections
export default class NavigationMenu extends Service {
  @service site;
  @service siteSettings;

  get isHeaderDropdownMode() {
    return this.siteSettings.navigation_menu === "header dropdown";
  }

  get isDesktopDropdownMode() {
    return this.site.desktopView && this.isHeaderDropdownMode;
  }
}
