import Service, { service } from "@ember/service";
import KeyValueStore from "discourse/lib/key-value-store";
import { ADMIN_PANEL, MAIN_PANEL } from "discourse/lib/sidebar/panels";

export default class AdminSidebarStateManager extends Service {
  @service sidebarState;

  STORE_NAMESPACE = "discourse_admin_sidebar_experiment_";
  keywords = {};
  store = new KeyValueStore(this.STORE_NAMESPACE);

  get navConfig() {
    return this.store.getObject("navConfig");
  }

  set navConfig(value) {
    this.store.setObject({ key: "navConfig", value });
  }

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

  maybeForceAdminSidebar(opts = {}) {
    opts.onlyIfAlreadyActive ??= true;

    const isAdminSidebarActive =
      this.sidebarState.currentPanel?.key === ADMIN_PANEL;

    if (!opts.onlyIfAlreadyActive) {
      return this.#forceAdminSidebar();
    }

    if (isAdminSidebarActive) {
      return this.#forceAdminSidebar();
    } else {
      this.sidebarState.isForcingSidebar = false;
      return false;
    }
  }

  stopForcingAdminSidebar() {
    this.sidebarState.setPanel(MAIN_PANEL);
    this.sidebarState.isForcingSidebar = false;
  }

  #forceAdminSidebar() {
    this.sidebarState.setPanel(ADMIN_PANEL);
    this.sidebarState.setSeparatedMode();
    this.sidebarState.hideSwitchPanelButtons();
    this.sidebarState.isForcingSidebar = true;
    return true;
  }
}
