import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { waitForPromise } from "@ember/test-waiters";
import ItsATrap from "@discourse/itsatrap";
import concatClass from "discourse/helpers/concat-class";
import scrollLock from "discourse/lib/scroll-lock";
import {
  getMaxAnimationTimeMs,
  shouldCloseMenu,
} from "discourse/lib/swipe-events";
import { isDocumentRTL } from "discourse/lib/text-direction";
import swipe from "discourse/modifiers/swipe";
import { isTesting } from "discourse-common/config/environment";
import discourseLater from "discourse-common/lib/later";
import { bind, debounce } from "discourse-common/utils/decorators";
import Header from "./header";

let _menuPanelClassesToForceDropdown = [];
const PANEL_WIDTH = 340;
const DEBOUNCE_HEADER_DELAY = 10;

export default class GlimmerSiteHeader extends Component {
  @service appEvents;
  @service currentUser;
  @service site;
  @service header;

  pxClosed;
  headerElement;

  _animate = false;
  _headerWrap;
  _mainOutletWrapper;
  _swipeMenuOrigin;
  _applicationElement;
  _resizeObserver;

  constructor() {
    super(...arguments);

    if (this.currentUser?.staff) {
      document.body.classList.add("staff");
    }

    schedule("afterRender", () => this.animateMenu());
  }

  get dropDownHeaderEnabled() {
    return !this.sidebarEnabled || this.site.narrowDesktopView;
  }

  get slideInMode() {
    return this.site.mobileView || this.site.narrowDesktopView;
  }

  get leftMenuClass() {
    if (isDocumentRTL()) {
      return "user-menu";
    } else {
      return "hamburger-panel";
    }
  }

  @bind
  updateOffsets() {
    // clamping to 0 to prevent negative values (hello, Safari)
    const headerWrapBottom = Math.max(
      0,
      Math.floor(this._headerWrap.getBoundingClientRect().bottom)
    );

    let mainOutletOffsetTop = Math.max(
      0,
      Math.floor(this._mainOutletWrapper.getBoundingClientRect().top) -
        headerWrapBottom
    );

    if (DEBUG && isTesting()) {
      mainOutletOffsetTop -= document
        .getElementById("ember-testing-container")
        .getBoundingClientRect().top;

      mainOutletOffsetTop -= 1; // For 1px border on testing container
    }

    const docStyle = document.documentElement.style;
    const currentHeaderOffset =
      parseInt(docStyle.getPropertyValue("--header-offset"), 10) || 0;
    const newHeaderOffset = headerWrapBottom;
    if (currentHeaderOffset !== newHeaderOffset) {
      docStyle.setProperty("--header-offset", `${newHeaderOffset}px`);
    }

    const currentMainOutletOffset =
      parseInt(docStyle.getPropertyValue("--main-outlet-offset"), 10) || 0;
    const newMainOutletOffset = headerWrapBottom + mainOutletOffsetTop;
    if (currentMainOutletOffset !== newMainOutletOffset) {
      docStyle.setProperty("--main-outlet-offset", `${newMainOutletOffset}px`);
    }
  }

  @debounce(DEBOUNCE_HEADER_DELAY)
  _recalculateHeaderOffset() {
    this._scheduleUpdateOffsets();
  }

  @bind
  _scheduleUpdateOffsets() {
    schedule("afterRender", this.updateOffsets);
  }

  @action
  setupHeader() {
    this.appEvents.on("user-menu:rendered", this, this.animateMenu);
    if (this.dropDownHeaderEnabled) {
      this.appEvents.on(
        "sidebar-hamburger-dropdown:rendered",
        this,
        this.animateMenu
      );
    }

    this._headerWrap = document.querySelector(".d-header-wrap");
    this._mainOutletWrapper = document.querySelector("#main-outlet-wrapper");
    if (this._headerWrap) {
      schedule("afterRender", () => {
        this.headerElement = this._headerWrap.querySelector("header.d-header");
      });

      window.addEventListener("scroll", this._recalculateHeaderOffset, {
        passive: true,
      });

      this._itsatrap = new ItsATrap(this.headerElement);
      const dirs = ["up", "down"];
      this._itsatrap.bind(dirs, (e) => this._handleArrowKeysNav(e));

      this._resizeObserver = new ResizeObserver(() => {
        this._recalculateHeaderOffset();
      });

      this._resizeObserver.observe(document.querySelector(".discourse-root"));
    }
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

  @action
  animateMenu() {
    const menuPanels = document.querySelectorAll(".menu-panel");

    if (menuPanels.length === 0) {
      this._animate = this.slideInMode;
      return;
    }

    let viewMode = this.slideInMode ? "slide-in" : "drop-down";

    menuPanels.forEach((panel) => {
      if (menuPanelContainsClass(panel)) {
        viewMode = "drop-down";
        this._animate = false;
      }

      const cloakElement = document.querySelector(".header-cloak");

      panel.classList.remove("drop-down");
      panel.classList.remove("slide-in");
      panel.classList.add(viewMode);

      if (this._animate) {
        let animationFinished = null;
        let finalPosition = PANEL_WIDTH;
        this._swipeMenuOrigin = "right";
        if (
          this.slideInMode &&
          panel.parentElement.classList.contains(this.leftMenuClass)
        ) {
          this._swipeMenuOrigin = "left";
          finalPosition = -PANEL_WIDTH;
        }
        animationFinished = panel.animate(
          [{ transform: `translate3d(${finalPosition}px, 0, 0)` }],
          {
            fill: "forwards",
          }
        ).finished;

        waitForPromise(animationFinished);

        cloakElement.animate([{ opacity: 0 }], { fill: "forwards" });
        cloakElement.style.display = "block";

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

  @bind
  _animateOpening(panel, event = null) {
    const cloakElement = document.querySelector(".header-cloak");
    let durationMs = getMaxAnimationTimeMs();
    if (event && this.pxClosed > 0) {
      durationMs = getMaxAnimationTimeMs(
        this.pxClosed / Math.abs(event.velocityX)
      );
    }
    const timing = {
      duration: durationMs > 0 ? durationMs : 0,
      fill: "forwards",
      easing: "ease-out",
    };
    panel.animate([{ transform: `translate3d(0, 0, 0)` }], timing);
    cloakElement?.animate?.([{ opacity: 1 }], timing);
    this.pxClosed = null;
  }

  @bind
  _animateClosing(event, panel, menuOrigin) {
    this._animate = true;
    const cloakElement = document.querySelector(".header-cloak");
    let durationMs = getMaxAnimationTimeMs();
    if (event && this.pxClosed > 0) {
      const distancePx = PANEL_WIDTH - this.pxClosed;
      durationMs = getMaxAnimationTimeMs(
        distancePx / Math.abs(event.velocityX)
      );
    }
    const timing = {
      duration: durationMs > 0 ? durationMs : 0,
      fill: "forwards",
    };

    let endPosition = -PANEL_WIDTH; //origin left
    if (menuOrigin === "right") {
      endPosition = PANEL_WIDTH;
    }
    panel.animate(
      [{ transform: `translate3d(${endPosition}px, 0, 0)` }],
      timing
    );
    if (cloakElement) {
      cloakElement.animate([{ opacity: 0 }], timing);
      cloakElement.style.display = "none";

      // to ensure that the cloak is cleared after animation we need to toggle any active menus
      if (this.header.hamburgerVisible || this.header.userVisible) {
        this.header.hamburgerVisible = false;
        this.header.userVisible = false;
      }
    }
    this.pxClosed = null;
  }

  @bind
  onSwipeStart(swipeEvent) {
    const center = swipeEvent.center;
    const swipeOverValidElement = document
      .elementsFromPoint(center.x, center.y)
      .some(
        (ele) =>
          ele.classList.contains("panel-body") ||
          ele.classList.contains("header-cloak")
      );
    if (
      swipeOverValidElement &&
      (swipeEvent.direction === "left" || swipeEvent.direction === "right")
    ) {
      scrollLock(true, document.querySelector(".panel-body"));
    } else {
      event.preventDefault();
    }
  }

  @bind
  onSwipeEnd(swipeEvent) {
    const menuPanels = document.querySelectorAll(".menu-panel");
    scrollLock(false, document.querySelector(".panel-body"));
    menuPanels.forEach((panel) => {
      if (shouldCloseMenu(swipeEvent, this._swipeMenuOrigin)) {
        this._animateClosing(swipeEvent, panel, this._swipeMenuOrigin);
        scrollLock(false);
      } else {
        this._animateOpening(panel, swipeEvent);
      }
    });
  }

  @bind
  onSwipeCancel() {
    const menuPanels = document.querySelectorAll(".menu-panel");
    scrollLock(false, document.querySelector(".panel-body"));
    menuPanels.forEach((panel) => {
      this._animateOpening(panel);
    });
  }

  @bind
  onSwipe(swipeEvent) {
    const movingElement = document.querySelector(".menu-panel");
    const cloakElement = document.querySelector(".header-cloak");

    //origin left
    this.pxClosed = Math.max(0, -swipeEvent.deltaX);
    let translation = -this.pxClosed;
    if (this._swipeMenuOrigin === "right") {
      this.pxClosed = Math.max(0, swipeEvent.deltaX);
      translation = this.pxClosed;
    }

    movingElement.animate(
      [{ transform: `translate3d(${translation}px, 0, 0)` }],
      {
        fill: "forwards",
      }
    );
    cloakElement?.animate?.(
      [
        {
          opacity: (PANEL_WIDTH - this.pxClosed) / PANEL_WIDTH,
        },
      ],
      { fill: "forwards" }
    );
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off("user-menu:rendered", this, this.animateMenu);

    if (this.dropDownHeaderEnabled) {
      this.appEvents.off(
        "sidebar-hamburger-dropdown:rendered",
        this,
        this.animateMenu
      );
    }

    this._itsatrap?.destroy();
    this._itsatrap = null;

    window.removeEventListener("scroll", this._recalculateHeaderOffset);
    this._resizeObserver?.disconnect();
  }

  <template>
    <div
      class={{concatClass
        (unless this.slideInMode "drop-down-mode")
        "d-header-wrap"
      }}
      {{didInsert this.setupHeader}}
      {{swipe
        onDidStartSwipe=this.onSwipeStart
        onDidEndSwipe=this.onSwipeEnd
        onDidCancelSwipe=this.onSwipeCancel
        onDidSwipe=this.onSwipe
        lockBody=false
      }}
    >
      <Header
        @canSignUp={{@canSignUp}}
        @showSidebar={{@showSidebar}}
        @sidebarEnabled={{@sidebarEnabled}}
        @toggleSidebar={{@toggleSidebar}}
        @showCreateAccount={{@showCreateAccount}}
        @showLogin={{@showLogin}}
        @animateMenu={{this.animateMenu}}
        @topicInfo={{this.header.topicInfo}}
        @topicInfoVisible={{this.header.topicInfoVisible}}
      />
    </div>
  </template>
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
