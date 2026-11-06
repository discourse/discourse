import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { cancel, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { waitForPromise } from "@ember/test-waiters";
import ItsATrap from "@discourse/itsatrap";
import runAfterFramePaint from "discourse/lib/after-frame-paint";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import { isTesting } from "discourse/lib/environment";
import discourseLater from "discourse/lib/later";
import {
  menuSheetClosedTransform,
  menuSheetEdge,
} from "discourse/lib/menu-sheet";
import scrollLock from "discourse/lib/scroll-lock";
import {
  dampenedOverdrag,
  getMaxAnimationTimeMs,
  shouldCloseMenu,
  shouldDeferSwipeToContent,
} from "discourse/lib/swipe-events";
import { isDocumentRTL } from "discourse/lib/text-direction";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dSwipe from "discourse/ui-kit/modifiers/d-swipe";
import Header from "./header.gjs";
import ImpersonationNotice from "./impersonation-notice.gjs";

let _menuPanelClassesToForceDropdown = [];
const PANEL_WIDTH = 340;

function isSheet(origin) {
  return origin === "bottom" || origin === "top";
}
// Matches mobile modals' entrance
const SHEET_ENTER_MS = 250;
const DEBOUNCE_HEADER_DELAY = 10;

export default class GlimmerSiteHeader extends Component {
  @service appEvents;
  @service currentUser;
  @service site;
  @service header;
  @service mobileTabBar;

  pxClosed;
  headerElement;

  #animatesRenderedHamburger = false;
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

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off("user-menu:rendered", this, this.animateMenu);

    if (this.#animatesRenderedHamburger) {
      this.appEvents.off(
        "sidebar-hamburger-dropdown:rendered",
        this,
        this.animateRenderedHamburger
      );
    }

    this._itsatrap?.destroy();
    this._itsatrap = null;

    window.removeEventListener("scroll", this.debouncedRecalculateHeaderOffset);
    this._resizeObserver.disconnect();
    cancel(this.recalculationTimer);
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

  get showImpersonationNotice() {
    return this.currentUser?.is_impersonating;
  }

  @bind
  debouncedRecalculateHeaderOffset() {
    this.recalculationTimer = discourseDebounce(
      this,
      this.recalculateHeaderOffset,
      DEBOUNCE_HEADER_DELAY
    );
  }

  recalculateHeaderOffset() {
    if (this.isDestroying) {
      return;
    }

    // We expect this to be zero, but when overscrolling in Safari it can have a non-zero value:
    const overscrollPx = Math.max(
      0,
      document.documentElement.getBoundingClientRect().top
    );

    // Tends to be zero, but is set higher when on iPad PWA with the 'footer-navigation' at top of screen
    const headerCssTop =
      parseInt(
        window.getComputedStyle(this._headerWrap).getPropertyValue("top"),
        10
      ) || 0;

    let headerWrapBottom =
      this._headerWrap.getBoundingClientRect().bottom - overscrollPx;

    // iOS Safari bug: when overscrolling at the bottom of the page on iOS, fixed/sticky elements report their position incorrectly.
    // Clamp the headerWrapBottom to the minimum possible value (top + height) to avoid this.
    const minimumPossibleHeaderWrapBottom =
      headerCssTop + this._headerWrap.getBoundingClientRect().height;
    headerWrapBottom = Math.max(
      headerWrapBottom,
      minimumPossibleHeaderWrapBottom
    );

    // Safari bug: while scrolling on iOS, fixed elements can have a viewport position which fluctuates by sub-pixel amounts.
    // To avoid that fluctuation affecting the header offset, we subtract that tiny fluctuation from the header-offset.
    const headerWrapTopDiff =
      this._headerWrap.getBoundingClientRect().top -
      overscrollPx -
      headerCssTop;
    if (Math.abs(headerWrapTopDiff) < 1) {
      headerWrapBottom -= headerWrapTopDiff;
    }

    let mainOutletOffsetTop = Math.max(
      0,
      this._mainOutletWrapper.getBoundingClientRect().top -
        headerWrapBottom -
        overscrollPx
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
    const newHeaderOffset = Math.floor(headerWrapBottom);
    if (currentHeaderOffset !== newHeaderOffset) {
      this.header.headerOffset = newHeaderOffset;
      docStyle.setProperty("--header-offset", `${newHeaderOffset}px`);
    }

    const currentMainOutletOffset =
      parseInt(docStyle.getPropertyValue("--main-outlet-offset"), 10) || 0;
    const newMainOutletOffset = Math.floor(
      headerWrapBottom + mainOutletOffsetTop
    );
    if (currentMainOutletOffset !== newMainOutletOffset) {
      this.header.mainOutletOffset = newMainOutletOffset;
      docStyle.setProperty("--main-outlet-offset", `${newMainOutletOffset}px`);
    }
  }

  @action
  setupHeader() {
    this.appEvents.on("user-menu:rendered", this, this.animateMenu);

    // The mobile tab bar opens the hamburger menu without the header's toggle
    this.#animatesRenderedHamburger =
      this.dropDownHeaderEnabled || this.mobileTabBar.enabled;
    if (this.#animatesRenderedHamburger) {
      this.appEvents.on(
        "sidebar-hamburger-dropdown:rendered",
        this,
        this.animateRenderedHamburger
      );
    }

    this._headerWrap = document.querySelector(".d-header-wrap");
    this._mainOutletWrapper = document.querySelector("#main-outlet-wrapper");
    if (this._headerWrap) {
      schedule("afterRender", () => {
        this.headerElement = this._headerWrap.querySelector("header.d-header");
      });

      window.addEventListener("scroll", this.debouncedRecalculateHeaderOffset, {
        passive: true,
      });

      this._itsatrap = new ItsATrap(this.headerElement);
      const dirs = ["up", "down"];
      this._itsatrap.bind(dirs, (e) => this._handleArrowKeysNav(e));

      this._resizeObserver = new ResizeObserver(
        this.debouncedRecalculateHeaderOffset
      );
      this._resizeObserver.observe(document.querySelector(".discourse-root"));
    }

    // the resize observer will not trigger on the first render, so we need to call it manually to get the initial value
    // set just after the header is inserted
    this.recalculateHeaderOffset();
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
        const sheetEdge = this.slideInMode && menuSheetEdge(panel);
        this._swipeMenuOrigin = "right";
        if (sheetEdge) {
          this._swipeMenuOrigin = sheetEdge;
        } else if (
          this.slideInMode &&
          panel.parentElement.classList.contains(this.leftMenuClass)
        ) {
          this._swipeMenuOrigin = "left";
        }
        const animationFinished = panel.animate(
          [{ transform: this.#closedTransform(panel, this._swipeMenuOrigin) }],
          {
            fill: "forwards",
          }
        ).finished;

        waitForPromise(animationFinished);

        if (cloakElement) {
          cloakElement.animate([{ opacity: 0 }], { fill: "forwards" });
          cloakElement.style.display = "block";
        }

        const origin = this._swipeMenuOrigin;
        animationFinished.then(() => {
          if (isSheet(origin)) {
            // Its content renders after a paint; moving before then would
            // show an empty sheet that fills in partway
            runAfterFramePaint(() => this._animateOpening(panel));
          } else if (isTesting()) {
            this._animateOpening(panel);
          } else {
            discourseLater(() => this._animateOpening(panel));
          }
        });
      }

      this._animate = false;
    });
  }

  animateRenderedHamburger() {
    this._animate = this.slideInMode;
    this.animateMenu();
  }

  @bind
  onSwipeStart(swipeEvent, fullEvent) {
    const center = swipeEvent.center;
    const swipeOverValidElement = document
      .elementsFromPoint(center.x, center.y)
      .some(
        (ele) =>
          ele.classList.contains("panel-body") ||
          ele.classList.contains("header-cloak")
      );

    // A sheet is dragged back past its edge to close, unless its content
    // scrolls that way instead
    const swipeClosesMenu = isSheet(this._swipeMenuOrigin)
      ? swipeEvent.direction ===
          (this._swipeMenuOrigin === "top" ? "up" : "down") &&
        !shouldDeferSwipeToContent(
          swipeEvent,
          document.querySelector(".menu-panel")
        )
      : swipeEvent.direction === "left" || swipeEvent.direction === "right";

    if (swipeOverValidElement && swipeClosesMenu) {
      scrollLock(true, document.querySelector(".panel-body"));
    } else {
      fullEvent.preventDefault();
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

    const origin = this._swipeMenuOrigin;
    const travel = this.#travel(movingElement, origin);
    let transform;

    if (isSheet(origin)) {
      // Resists being pulled past its open position, as modals do
      const toward = origin === "top" ? -1 : 1;
      const closing = swipeEvent.deltaY * toward;
      const translation =
        (closing >= 0 ? closing : -dampenedOverdrag(-closing)) * toward;
      this.pxClosed = Math.max(0, closing);
      transform = `translate3d(0, ${translation}px, 0)`;
    } else if (origin === "right") {
      this.pxClosed = Math.max(0, swipeEvent.deltaX);
      transform = `translate3d(${this.pxClosed}px, 0, 0)`;
    } else {
      this.pxClosed = Math.max(0, -swipeEvent.deltaX);
      transform = `translate3d(${-this.pxClosed}px, 0, 0)`;
    }

    movingElement.animate([{ transform }], { fill: "forwards" });
    cloakElement?.animate?.([{ opacity: (travel - this.pxClosed) / travel }], {
      fill: "forwards",
    });
  }

  #travel(panel, origin) {
    return isSheet(origin) ? panel.offsetHeight : PANEL_WIDTH;
  }

  #speed(event, origin) {
    return Math.abs(isSheet(origin) ? event.velocityY : event.velocityX);
  }

  #closedTransform(panel, origin) {
    switch (origin) {
      case "bottom":
      case "top":
        return menuSheetClosedTransform(origin);
      case "left":
        return `translate3d(${-PANEL_WIDTH}px, 0, 0)`;
      default:
        return `translate3d(${PANEL_WIDTH}px, 0, 0)`;
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

  @bind
  _animateOpening(panel, event = null) {
    const cloakElement = document.querySelector(".header-cloak");
    let durationMs = getMaxAnimationTimeMs();
    if (event && this.pxClosed > 0) {
      durationMs = getMaxAnimationTimeMs(
        this.pxClosed / this.#speed(event, this._swipeMenuOrigin)
      );
    }
    const timing = {
      duration: durationMs > 0 ? durationMs : 0,
      fill: "forwards",
      easing: "ease-out",
    };
    if (!event && isSheet(this._swipeMenuOrigin) && durationMs > 0) {
      timing.duration = SHEET_ENTER_MS;
      timing.easing = "ease";
    }
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
      const distancePx = this.#travel(panel, menuOrigin) - this.pxClosed;
      durationMs = getMaxAnimationTimeMs(
        distancePx / this.#speed(event, menuOrigin)
      );
    }
    const timing = {
      duration: durationMs > 0 ? durationMs : 0,
      fill: "forwards",
    };

    panel.animate(
      [{ transform: this.#closedTransform(panel, menuOrigin) }],
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

  <template>
    <div
      class={{dConcatClass
        (unless this.slideInMode "drop-down-mode")
        "d-header-wrap"
      }}
      {{didInsert this.setupHeader}}
      {{dSwipe
        onDidStartSwipe=this.onSwipeStart
        onDidEndSwipe=this.onSwipeEnd
        onDidCancelSwipe=this.onSwipeCancel
        onDidSwipe=this.onSwipe
        lockBody=false
      }}
    >
      {{#if this.showImpersonationNotice}}
        <ImpersonationNotice />
      {{/if}}
      <Header
        @animateMenu={{this.animateMenu}}
        @canSignUp={{@canSignUp}}
        @showCreateAccount={{@showCreateAccount}}
        @showLogin={{@showLogin}}
        @showSidebar={{@showSidebar}}
        @sidebarEnabled={{@sidebarEnabled}}
        @toggleSidebar={{@toggleSidebar}}
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
