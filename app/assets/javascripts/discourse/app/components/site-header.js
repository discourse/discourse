import { DEBUG } from "@glimmer/env";
import { schedule } from "@ember/runloop";
import { waitForPromise } from "@ember/test-waiters";
import ItsATrap from "@discourse/itsatrap";
import MountWidget from "discourse/components/mount-widget";
import { topicTitleDecorators } from "discourse/components/topic-title";
import scrollLock from "discourse/lib/scroll-lock";
import SwipeEvents, {
  getMaxAnimationTimeMs,
  shouldCloseMenu,
} from "discourse/lib/swipe-events";
import { isDocumentRTL } from "discourse/lib/text-direction";
import Docking from "discourse/mixins/docking";
import RerenderOnDoNotDisturbChange from "discourse/mixins/rerender-on-do-not-disturb-change";
import { isTesting } from "discourse-common/config/environment";
import discourseLater from "discourse-common/lib/later";
import { bind, observes } from "discourse-common/utils/decorators";

let _menuPanelClassesToForceDropdown = [];

const SiteHeaderComponent = MountWidget.extend(
  Docking,
  RerenderOnDoNotDisturbChange,
  {
    widget: "header",
    docAt: null,
    dockedHeader: null,
    _animate: false,
    _swipeMenuOrigin: "right",
    _topic: null,
    _itsatrap: null,
    _applicationElement: null,
    _PANEL_WIDTH: 340,
    _swipeEvents: null,

    @observes(
      "currentUser.unread_notifications",
      "currentUser.unread_high_priority_notifications",
      "currentUser.all_unread_notifications_count",
      "currentUser.reviewable_count",
      "currentUser.unseen_reviewable_count",
      "session.defaultColorSchemeIsDark",
      "session.darkModeAvailable"
    )
    notificationsChanged() {
      this.queueRerender();
    },

    @observes("site.narrowDesktopView")
    narrowDesktopViewChanged() {
      this.eventDispatched("dom:clean", "header");

      if (this._dropDownHeaderEnabled()) {
        this.appEvents.on(
          "sidebar-hamburger-dropdown:rendered",
          this,
          "_animateMenu"
        );
      }
    },

    _animateOpening(panel, event = null) {
      const headerCloak = document.querySelector(".header-cloak");
      let durationMs = getMaxAnimationTimeMs();
      if (event && this.pxClosed > 0) {
        durationMs = getMaxAnimationTimeMs(
          this.pxClosed / Math.abs(event.velocityX)
        );
      }
      const timing = {
        duration: durationMs,
        fill: "forwards",
        easing: "ease-out",
      };
      panel.animate([{ transform: `translate3d(0, 0, 0)` }], timing);
      headerCloak.animate([{ opacity: 1 }], timing);
      this.pxClosed = null;
    },

    _animateClosing(event, panel, menuOrigin) {
      this._animate = true;
      const headerCloak = document.querySelector(".header-cloak");
      let durationMs = getMaxAnimationTimeMs();
      if (event && this.pxClosed > 0) {
        const distancePx = this._PANEL_WIDTH - this.pxClosed;
        durationMs = getMaxAnimationTimeMs(
          distancePx / Math.abs(event.velocityX)
        );
      }
      const timing = {
        duration: durationMs,
        fill: "forwards",
      };

      let endPosition = -this._PANEL_WIDTH; //origin left
      if (menuOrigin === "right") {
        endPosition = this._PANEL_WIDTH;
      }
      panel
        .animate([{ transform: `translate3d(${endPosition}px, 0, 0)` }], timing)
        .finished.then(() => {
          schedule("afterRender", () => {
            this.eventDispatched("dom:clean", "header");
          });
        });

      headerCloak.animate([{ opacity: 0 }], timing);
      this.pxClosed = null;
    },

    _leftMenuClass() {
      return isDocumentRTL() ? "user-menu" : "hamburger-panel";
    },

    @bind
    onSwipeStart(event) {
      const e = event.detail;
      const center = e.center;
      const swipeOverValidElement = document
        .elementsFromPoint(center.x, center.y)
        .some(
          (ele) =>
            ele.classList.contains("panel-body") ||
            ele.classList.contains("header-cloak")
        );
      if (
        swipeOverValidElement &&
        (e.direction === "left" || e.direction === "right")
      ) {
        this.movingElement = document.querySelector(".menu-panel");
        this.cloakElement = document.querySelector(".header-cloak");
        scrollLock(true, document.querySelector(".panel-body"));
      } else {
        event.preventDefault();
      }
    },

    @bind
    onSwipeEnd(event) {
      const e = event.detail;
      const menuPanels = document.querySelectorAll(".menu-panel");
      const menuOrigin = this._swipeMenuOrigin;
      scrollLock(false, document.querySelector(".panel-body"));
      menuPanels.forEach((panel) => {
        if (shouldCloseMenu(e, menuOrigin)) {
          this._animateClosing(e, panel, menuOrigin);
        } else {
          this._animateOpening(panel, e);
        }
      });
    },

    @bind
    onSwipeCancel() {
      const menuPanels = document.querySelectorAll(".menu-panel");
      scrollLock(false, document.querySelector(".panel-body"));
      menuPanels.forEach((panel) => {
        this._animateOpening(panel);
      });
    },

    @bind
    onSwipe(event) {
      const e = event.detail;
      const panel = this.movingElement;
      const headerCloak = this.cloakElement;

      //origin left
      this.pxClosed = Math.max(0, -e.deltaX);
      let translation = -this.pxClosed;
      if (this._swipeMenuOrigin === "right") {
        this.pxClosed = Math.max(0, e.deltaX);
        translation = this.pxClosed;
      }
      panel.animate([{ transform: `translate3d(${translation}px, 0, 0)` }], {
        fill: "forwards",
      });
      headerCloak.animate(
        [
          {
            opacity: (this._PANEL_WIDTH - this.pxClosed) / this._PANEL_WIDTH,
          },
        ],
        { fill: "forwards" }
      );
    },

    dockCheck() {
      const header = this.header;

      if (this.docAt === null) {
        if (!header) {
          return;
        }
        this.docAt = header.offsetTop;
      }

      const main = (this._applicationElement ??=
        document.querySelector(".ember-application"));
      const offsetTop = main ? main.offsetTop : 0;
      const offset = window.pageYOffset - offsetTop;
      if (offset >= this.docAt) {
        if (!this.dockedHeader) {
          document.body.classList.add("docked");
          this.dockedHeader = true;
        }
      } else {
        if (this.dockedHeader) {
          document.body.classList.remove("docked");
          this.dockedHeader = false;
        }
      }
    },

    setTopic(topic) {
      this.eventDispatched("dom:clean", "header");
      this._topic = topic;
      this.queueRerender();
    },

    willRender() {
      this._super(...arguments);

      if (this.get("currentUser.staff")) {
        document.body.classList.add("staff");
      }
    },

    didInsertElement() {
      this._super(...arguments);
      this._resizeDiscourseMenuPanel = () => this.afterRender();
      window.addEventListener("resize", this._resizeDiscourseMenuPanel);

      this.appEvents.on("header:show-topic", this, "setTopic");
      this.appEvents.on("header:hide-topic", this, "setTopic");

      this.appEvents.on("user-menu:rendered", this, "_animateMenu");

      if (this._dropDownHeaderEnabled()) {
        this.appEvents.on(
          "sidebar-hamburger-dropdown:rendered",
          this,
          "_animateMenu"
        );
      }

      this.dispatch("notifications:changed", "user-notifications");
      this.dispatch("header:keyboard-trigger", "header");
      this.dispatch("user-menu:navigation", "user-menu");

      this.appEvents.on("dom:clean", this, "_cleanDom");

      if (this.currentUser) {
        this.currentUser.on("status-changed", this, "queueRerender");
      }

      const header = document.querySelector("header.d-header");
      this._itsatrap = new ItsATrap(header);
      const dirs = ["up", "down"];
      this._itsatrap.bind(dirs, (e) => this._handleArrowKeysNav(e));
    },

    _handleArrowKeysNav(event) {
      const activeTab = document.querySelector(
        ".menu-tabs-container .btn.active"
      );
      if (activeTab) {
        let activeTabNumber = Number(
          document.activeElement.dataset.tabNumber ||
            activeTab.dataset.tabNumber
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
    },

    _cleanDom() {
      // For performance, only trigger a re-render if any menu panels are visible
      if (this.element.querySelector(".menu-panel")) {
        this.eventDispatched("dom:clean", "header");
      }
    },

    willDestroyElement() {
      this._super(...arguments);

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
    },

    buildArgs() {
      return {
        topic: this._topic,
        canSignUp: this.canSignUp,
        sidebarEnabled: this.sidebarEnabled,
        showSidebar: this.showSidebar,
        navigationMenuQueryParamOverride: this.navigationMenuQueryParamOverride,
      };
    },

    afterRender() {
      const headerTitle = document.querySelector(".header-title .topic-link");
      if (headerTitle && this._topic) {
        topicTitleDecorators.forEach((cb) =>
          cb(this._topic, headerTitle, "header-title")
        );
      }
      this._animateMenu();
    },

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
    },

    _dropDownHeaderEnabled() {
      return !this.sidebarEnabled || this.site.narrowDesktopView;
    },
  }
);

function menuPanelContainsClass(menuPanel) {
  if (!_menuPanelClassesToForceDropdown) {
    return false;
  }

  // Check if any of the classNames are present in the node's classList
  for (let className of _menuPanelClassesToForceDropdown) {
    if (menuPanel.classList.contains(className)) {
      // Found a matching class
      return true;
    }
  }

  // No matching class found
  return false;
}

export function forceDropdownForMenuPanels(classNames) {
  // If classNames is a string, convert it to an array
  if (typeof classNames === "string") {
    classNames = [classNames];
  }
  return _menuPanelClassesToForceDropdown.push(...classNames);
}

export default SiteHeaderComponent.extend({
  classNames: ["d-header-wrap"],
  classNameBindings: ["site.mobileView::drop-down-mode"],
  headerWrap: null,
  header: null,

  init() {
    this._super(...arguments);
    this._resizeObserver = null;
  },

  @bind
  updateHeaderOffset() {
    // Safari likes overscolling the page (on both iOS and macOS).
    // This shows up as a negative value in window.scrollY.
    // We can use this to offset the headerWrap's top offset to avoid
    // jitteriness and bad positioning.
    const windowOverscroll = Math.min(0, window.scrollY);

    // The headerWrap's top offset can also be a negative value on Safari,
    // because of the changing height of the viewport (due to the URL bar).
    // For our use case, it's best to ensure this is clamped to 0.
    const headerWrapTop = Math.max(
      0,
      Math.floor(this.headerWrap.getBoundingClientRect().top)
    );
    let offsetTop = headerWrapTop + windowOverscroll;

    if (DEBUG && isTesting()) {
      offsetTop -= document
        .getElementById("ember-testing-container")
        .getBoundingClientRect().top;

      offsetTop -= 1; // For 1px border on testing container
    }

    const documentStyle = document.documentElement.style;

    const currentValue =
      parseInt(documentStyle.getPropertyValue("--header-offset"), 10) || 0;
    const newValue = this.headerWrap.offsetHeight + offsetTop;

    if (currentValue !== newValue) {
      documentStyle.setProperty("--header-offset", `${newValue}px`);
    }
  },

  @bind
  onScroll() {
    schedule("afterRender", this.updateHeaderOffset);
  },

  didInsertElement() {
    this._super(...arguments);

    this.appEvents.on("site-header:force-refresh", this, "queueRerender");

    this.headerWrap = document.querySelector(".d-header-wrap");

    if (this.headerWrap) {
      schedule("afterRender", () => {
        this.header = this.headerWrap.querySelector("header.d-header");
        this.updateHeaderOffset();
        const headerTop = this.header.offsetTop;
        document.documentElement.style.setProperty(
          "--header-top",
          `${headerTop}px`
        );
      });

      window.addEventListener("scroll", this.onScroll, {
        passive: true,
      });
    }

    this._resizeObserver = new ResizeObserver((entries) => {
      for (let entry of entries) {
        if (entry.contentRect) {
          const headerTop = this.header?.offsetTop;
          document.documentElement.style.setProperty(
            "--header-top",
            `${headerTop}px`
          );
          this.updateHeaderOffset();
        }
      }
    });

    this._resizeObserver.observe(this.headerWrap);

    this._swipeEvents = new SwipeEvents(this.element);
    if (this.site.mobileView) {
      this._swipeEvents.addTouchListeners();
      this.element.addEventListener("swipestart", this.onSwipeStart);
      this.element.addEventListener("swipeend", this.onSwipeEnd);
      this.element.addEventListener("swipecancel", this.onSwipeCancel);
      this.element.addEventListener("swipe", this.onSwipe);
    }
  },

  willDestroyElement() {
    this._super(...arguments);
    window.removeEventListener("scroll", this.onScroll);
    this._resizeObserver?.disconnect();
    this.appEvents.off("site-header:force-refresh", this, "queueRerender");
    if (this.site.mobileView) {
      this.element.removeEventListener("swipestart", this.onSwipeStart);
      this.element.removeEventListener("swipeend", this.onSwipeEnd);
      this.element.removeEventListener("swipecancel", this.onSwipeCancel);
      this.element.removeEventListener("swipe", this.onSwipe);
      this._swipeEvents.removeTouchListeners();
    }
  },
});
