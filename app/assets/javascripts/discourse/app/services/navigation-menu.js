import Service, { inject as service } from "@ember/service";

export default class NavigationMenu extends Service {
  @service site;
  @service siteSettings;

  get isDesktopDropdownMode() {
    const headerDropdownMode =
      this.siteSettings.navigation_menu === "header dropdown";

    return !this.site.mobileView && headerDropdownMode;
  }
}
