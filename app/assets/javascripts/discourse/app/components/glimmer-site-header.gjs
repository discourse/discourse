import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";

export default class GlimmerSiteHeader extends Component {
  @tracked dockedHeader = false;
  @tracked _topic = null;

  get currentUser() {
    // Implement the logic to get the current user
    // Replace `currentUser` with the actual code to get the current user
    return currentUser;
  }

  get canSignUp() {
    // Implement the logic to check if sign up is allowed
    // Replace `canSignUp` with the actual code to check if sign up is allowed
    return canSignUp;
  }

  get sidebarEnabled() {
    // Implement the logic to check if sidebar is enabled
    // Replace `sidebarEnabled` with the actual code to check if sidebar is enabled
    return sidebarEnabled;
  }

  get showSidebar() {
    // Implement the logic to check if sidebar should be shown
    // Replace `showSidebar` with the actual code to check if sidebar should be shown
    return showSidebar;
  }

  get navigationMenuQueryParamOverride() {
    // Implement the logic to get the navigation menu query param override
    // Replace `navigationMenuQueryParamOverride` with the actual code to get the navigation menu query param override
    return navigationMenuQueryParamOverride;
  }

  constructor() {
    super(...arguments);
    this._resizeDiscourseMenuPanel = () => this.afterRender();
    window.addEventListener("resize", this._resizeDiscourseMenuPanel);
  }

  // didInsertElement() {
  //   super.didInsertElement(...arguments);
  //   this.appEvents.on("header:show-topic", this, "setTopic");
  //   this.appEvents.on("header:hide-topic", this, "setTopic");
  //   this.appEvents.on("user-menu:rendered", this, "_animateMenu");

  //   if (this._dropDownHeaderEnabled()) {
  //     this.appEvents.on(
  //       "sidebar-hamburger-dropdown:rendered",
  //       this,
  //       "_animateMenu"
  //     );
  //   }

  //   this.dispatch("notifications:changed", "user-notifications");
  //   this.dispatch("header:keyboard-trigger", "header");
  //   this.dispatch("user-menu:navigation", "user-menu");

  //   this.appEvents.on("dom:clean", this, "_cleanDom");

  //   if (this.currentUser) {
  //     this.currentUser.on("status-changed", this, "queueRerender");
  //   }

  //   const header = document.querySelector("header.d-header");
  //   this._itsatrap = new ItsATrap(header);
  //   const dirs = ["up", "down"];
  //   this._itsatrap.bind(dirs, (e) => this._handleArrowKeysNav(e));
  // }

  willDestroy() {
    super.willDestroy(...arguments);
    window.removeEventListener("resize", this._resizeDiscourseMenuPanel);
    this.appEvents.off("header:show-topic", this, "setTopic");
    this.appEvents.off("header:hide-topic", this, "setTopic");
    this.appEvents.off("dom:clean", this, "_cleanDom");
    this.appEvents.off("user-menu:rendered", this, "_animateMenu");

    if (this._dropDownHeaderEnabled()) {
      this.appEvents.off(
        "sidebar-hamburger-dropdown:rendered",
        this,
        "_animateMenu"
      );
    }

    if (this.currentUser) {
      this.currentUser.off("status-changed", this, "queueRerender");
    }

    this._itsatrap?.destroy();
    this._itsatrap = null;
  }

  setTopic(topic) {
    this.eventDispatched("dom:clean", "header");
    this._topic = topic;
    this.queueRerender();
  }

  willRender() {
    super.willRender(...arguments);

    if (this.get("currentUser.staff")) {
      document.body.classList.add("staff");
    }
  }

  afterRender() {
    super.afterRender(...arguments);
    const headerTitle = document.querySelector(".header-title .topic-link");
    if (headerTitle && this._topic) {
      topicTitleDecorators.forEach((cb) =>
        cb(this._topic, headerTitle, "header-title")
      );
    }
    this._animateMenu();
  }

  _handleArrowKeysNav(event) {
    const activeTab = document.querySelector(
      ".menu-tabs-container .btn.active"
    );
    if (activeTab) {
      let activeTabNumber = Number(
        document.activeElement.dataset.tabNumber || activeTab.dataset.tabNumber
      );
      const maxTabNumber =
        document.querySelectorAll(".menu-tabs-container .btn").length - 1;
      const isNext = event.key === "ArrowDown";
      let nextTab = isNext ? activeTabNumber + 1 : activeTabNumber - 1;
      if (isNext && nextTab > maxTabNumber) {
        nextTab = 0;
      }
      if (!isNext && nextTab < 0) {
        nextTab = maxTabNumber;
      }
      event.preventDefault();
      document
        .querySelector(
          `.menu-tabs-container .btn[data-tab-number='${nextTab}']`
        )
        .focus();
    }
  }

  _cleanDom() {
    if (this.element.querySelector(".menu-panel")) {
      this.eventDispatched("dom:clean", "header");
    }
  }

  _animateMenu() {
    const menuPanels = document.querySelectorAll(".menu-panel");

    if (menuPanels.length === 0) {
      this._animate = this.site.mobileView || this.site.narrowDesktopView;
      return;
    }

    let viewMode =
      this.site.mobileView || this.site.narrowDesktopView
        ? "slide-in"
        : "drop-down";

    menuPanels.forEach((panel) => {
      if (menuPanelContainsClass(panel)) {
        viewMode = "drop-down";
        this._animate = false;
      }

      const headerCloak = document.querySelector(".header-cloak");

      panel.classList.remove("drop-down");
      panel.classList.remove("slide-in");
      panel.classList.add(viewMode);

      if (this._animate) {
        let animationFinished = null;
        let finalPosition = this._PANEL_WIDTH;
        this._swipeMenuOrigin = "right";
        if (
          (this.site.mobileView || this.site.narrowDesktopView) &&
          panel.parentElement.classList.contains(this._leftMenuClass())
        ) {
          this._swipeMenuOrigin = "left";
          finalPosition = -this._PANEL_WIDTH;
        }
        animationFinished = panel.animate(
          [{ transform: `translate3d(${finalPosition}px, 0, 0)` }],
          {
            fill: "forwards",
          }
        ).finished;

        if (isTesting()) {
          waitForPromise(animationFinished);
        }

        headerCloak.animate([{ opacity: 0 }], { fill: "forwards" });
        headerCloak.style.display = "block";

        animationFinished.then(() => {
          if (isTesting()) {
            this._animateOpening(panel);
          } else {
            discourseLater(() => this._animateOpening(panel));
          }
        });
      }

      this._animate = false;
    });
  }

  _dropDownHeaderEnabled() {
    return !this.sidebarEnabled || this.site.narrowDesktopView;
  }
}

function menuPanelContainsClass(menuPanel) {
  if (!_menuPanelClassesToForceDropdown) {
    return false;
  }

  for (let className of _menuPanelClassesToForceDropdown) {
    if (menuPanel.classList.contains(className)) {
      return true;
    }
  }

  return false;
}

export function forceDropdownForMenuPanels(classNames) {
  if (typeof classNames === "string") {
    classNames = [classNames];
  }
  return _menuPanelClassesToForceDropdown.push(...classNames);
}
