import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import KeyValueStore from "discourse/lib/key-value-store";
import { ADMIN_PANEL } from "discourse/lib/sidebar/panels";

export default class AdminSidebarStateManager extends Service {
  @service sidebarState;
  @service currentUser;
  @tracked keywords = new TrackedObject();

  STORE_NAMESPACE = "discourse_admin_sidebar_experiment_";

  store = new KeyValueStore(this.STORE_NAMESPACE);

  get navConfig() {
    return this.store.getObject("navConfig");
  }

  set navConfig(value) {
    this.store.setObject({ key: "navConfig", value });
  }

  get currentUserUsingAdminSidebar() {
    return this.currentUser.use_admin_sidebar;
  }

  maybeForceAdminSidebar(opts = {}) {
    opts.onlyIfAlreadyActive ??= true;

    const isAdminSidebarActive =
      this.sidebarState.currentPanel?.key === ADMIN_PANEL;

    if (!this.currentUserUsingAdminSidebar) {
      return false;
    }

    if (!opts.onlyIfAlreadyActive) {
      return this.#forceAdminSidebar();
    }

    if (isAdminSidebarActive) {
      return this.#forceAdminSidebar();
    } else {
      return false;
    }
  }

  #forceAdminSidebar() {
    this.sidebarState.setPanel(ADMIN_PANEL);
    this.sidebarState.setSeparatedMode();
    this.sidebarState.hideSwitchPanelButtons();
    return true;
  }
}
