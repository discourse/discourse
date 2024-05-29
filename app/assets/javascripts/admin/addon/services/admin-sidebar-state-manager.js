import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import KeyValueStore from "discourse/lib/key-value-store";
import { ADMIN_PANEL, MAIN_PANEL } from "discourse/lib/sidebar/panels";

export default class AdminSidebarStateManager extends Service {
  @service sidebarState;
  @service currentUser;

  @tracked isForcingAdminSidebar = false;

  keywords = {};

  STORE_NAMESPACE = "discourse_admin_sidebar_experiment_";

  store = new KeyValueStore(this.STORE_NAMESPACE);

  setLinkKeywords(link_name, keywords) {
    if (!this.keywords[link_name]) {
      this.keywords[link_name] = {
        navigation: keywords.map((keyword) => keyword.toLowerCase()),
      };
      return;
    }

    this.keywords[link_name].navigation = [
      ...new Set(
        this.keywords[link_name].navigation.concat(
          keywords.map((keyword) => keyword.toLowerCase())
        )
      ),
    ];
  }

  get navConfig() {
    return this.store.getObject("navConfig");
  }

  set navConfig(value) {
    this.store.setObject({ key: "navConfig", value });
  }

  get currentUserUsingAdminSidebar() {
    return this.currentUser?.use_admin_sidebar;
  }

  maybeForceAdminSidebar(opts = {}) {
    opts.onlyIfAlreadyActive ??= true;

    const isAdminSidebarActive =
      this.sidebarState.currentPanel?.key === ADMIN_PANEL;

    if (!this.currentUserUsingAdminSidebar) {
      this.isForcingAdminSidebar = false;
      return false;
    }

    if (!opts.onlyIfAlreadyActive) {
      return this.#forceAdminSidebar();
    }

    if (isAdminSidebarActive) {
      return this.#forceAdminSidebar();
    } else {
      this.isForcingAdminSidebar = false;
      return false;
    }
  }

  stopForcingAdminSidebar() {
    this.sidebarState.setPanel(MAIN_PANEL);
    this.isForcingAdminSidebar = false;
  }

  #forceAdminSidebar() {
    this.sidebarState.setPanel(ADMIN_PANEL);
    this.sidebarState.setSeparatedMode();
    this.sidebarState.hideSwitchPanelButtons();
    this.isForcingAdminSidebar = true;
    return true;
  }
}
