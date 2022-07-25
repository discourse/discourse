export default class UserMenuTab {
  constructor(currentUser, siteSettings, site) {
    this.currentUser = currentUser;
    this.siteSettings = siteSettings;
    this.site = site;
  }

  get shouldDisplay() {
    return true;
  }

  get count() {
    return 0;
  }

  get panelComponent() {
    throw new Error("not implemented");
  }

  get id() {
    throw new Error("not implemented");
  }

  get icon() {
    throw new Error("not implemented");
  }
}
