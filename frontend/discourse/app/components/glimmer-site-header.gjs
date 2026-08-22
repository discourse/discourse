import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { cancel, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { waitForPromise } from "@ember/test-waiters";
import ItsATrap from "@discourse/itsatrap";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import { isTesting } from "discourse/lib/environment";
import discourseLater from "discourse/lib/later";
import scrollLock from "discourse/lib/scroll-lock";
import {
  dampenedOverdrag,
  getMaxAnimationTimeMs,
} from "discourse/lib/swipe-events";
import { isDocumentRTL } from "discourse/lib/text-direction";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { registerPointerDrag } from "discourse/ui-kit/modifiers/d-pointer-drag";
import Header from "./header";
import ImpersonationNotice from "./impersonation-notice";

let _menuPanelClassesToForceDropdown = [];
const PANEL_WIDTH = 340;
const DEBOUNCE_HEADER_DELAY = 10;
const DRAWER_SETTLE_EASING = "cubic-bezier(0.32, 0.72, 0, 1)";
const DRAWER_CLOSE_DISTANCE_RATIO = 0.25;
const DRAWER_CLOSE_VELOCITY_THRESHOLD = 0.4;

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
  _drawerDragAxis;
  _drawerDragPanel;
  _drawerDragStartedOnCloak = false;
  _drawerDragWidth = PANEL_WIDTH;
  _drawerVelocityX = 0;
  _drawerLastX;
  _drawerLastTime;
  _drawerGestureCleanups = new Map();
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

    if (this.dropDownHeaderEnabled) {
      this.appEvents.off(
        "sidebar-hamburger-dropdown:rendered",
        this,
        this.animateMenu
      );
    }

    this._itsatrap?.destroy();
    this._itsatrap = null;

    window.removeEventListener("scroll", this.debouncedRecalculateHeaderOffset);
    this._resizeObserver.disconnect();
    cancel(this.recalculationTimer);
    this.#unlockDrawerDrag();
    this.#clearDrawerGestures();
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
    if (this.isDestroying || this.isDestroyed) {
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
      this.#clearDrawerGestures();
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

      if (
        viewMode === "slide-in" &&
        (this.header.hamburgerVisible || this.header.userVisible)
      ) {
        this.#syncDrawerGestures(panel, cloakElement);
      } else {
        this.#clearDrawerGestures();
      }

      if (this._animate) {
        let animationFinished;
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

        if (cloakElement) {
          cloakElement.animate([{ opacity: 0 }], { fill: "forwards" });
          cloakElement.style.display = "block";
        }

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
      easing: DRAWER_SETTLE_EASING,
    };
    const animations = [
      panel.animate([{ transform: `translate3d(0, 0, 0)` }], timing).finished,
    ];
    if (cloakElement) {
      cloakElement.style.display = "block";
      animations.push(cloakElement.animate([{ opacity: 1 }], timing).finished);
    }

    waitForPromise(Promise.all(animations));
    this.pxClosed = null;
  }

  @bind
  _animateClosing(event, panel, menuOrigin) {
    this._animate = true;
    const cloakElement = document.querySelector(".header-cloak");
    const panelWidth = panel.getBoundingClientRect().width || PANEL_WIDTH;
    let durationMs = getMaxAnimationTimeMs();
    if (event && this.pxClosed > 0) {
      const distancePx = panelWidth - this.pxClosed;
      durationMs = getMaxAnimationTimeMs(
        distancePx / Math.abs(event.velocityX)
      );
    }
    const timing = {
      duration: durationMs > 0 ? durationMs : 0,
      fill: "forwards",
      easing: DRAWER_SETTLE_EASING,
    };

    let endPosition = -panelWidth; //origin left
    if (menuOrigin === "right") {
      endPosition = panelWidth;
    }
    const animations = [
      panel.animate(
        [{ transform: `translate3d(${endPosition}px, 0, 0)` }],
        timing
      ).finished,
    ];
    if (cloakElement) {
      animations.push(cloakElement.animate([{ opacity: 0 }], timing).finished);
    }

    const closingFinished = Promise.all(animations).then(() => {
      this.#clearDrawerGestures();

      if (cloakElement) {
        cloakElement.style.display = "none";
      }

      if (this.header.hamburgerVisible || this.header.userVisible) {
        this.header.hamburgerVisible = false;
        this.header.userVisible = false;
      }
    });

    waitForPromise(closingFinished);
    this.pxClosed = null;
  }

  @bind
  onDrawerDragStart(event) {
    const target = event.target;
    if (!this.site.mobileView || !(target instanceof Element)) {
      return false;
    }

    const panelAtPointer = target.closest(".menu-panel.slide-in");
    const cloakAtPointer = target.closest(".header-cloak");
    if (!panelAtPointer && !cloakAtPointer) {
      return false;
    }

    if (target.closest("input, textarea, select, [contenteditable='true']")) {
      return false;
    }

    const panel =
      panelAtPointer ?? document.querySelector(".menu-panel.slide-in");
    if (!panel) {
      return false;
    }

    // The cloak's outside-press handler must not dismiss the menu before this
    // gesture has had a chance to drag it. A release without movement closes it
    // below, preserving the ordinary tap-to-dismiss path.
    if (cloakAtPointer) {
      event.stopPropagation();
    }

    this._drawerDragPanel = panel;
    this._drawerDragStartedOnCloak = Boolean(cloakAtPointer);
    this._drawerDragAxis = null;
    this._drawerVelocityX = 0;
    this._drawerLastX = event.clientX;
    this._drawerLastTime = event.timeStamp;
    this._drawerDragWidth = panel.getBoundingClientRect().width || PANEL_WIDTH;
    this.pxClosed = 0;
    this._swipeMenuOrigin = panel.parentElement.classList.contains(
      this.leftMenuClass
    )
      ? "left"
      : "right";
  }

  @bind
  onDrawerDrag(event, dragInfo) {
    if (!this._drawerDragPanel) {
      return;
    }

    if (!this._drawerDragAxis) {
      this._drawerDragAxis =
        Math.abs(dragInfo.delta.x) >= Math.abs(dragInfo.delta.y)
          ? "horizontal"
          : "vertical";

      if (this._drawerDragAxis === "horizontal") {
        scrollLock(true, this._drawerDragPanel.querySelector(".panel-body"));
      }
    }

    if (this._drawerDragAxis !== "horizontal") {
      return;
    }

    this.#updateDrawerVelocity(event);

    const closingDelta =
      this._swipeMenuOrigin === "right" ? dragInfo.delta.x : -dragInfo.delta.x;
    this.pxClosed = Math.min(this._drawerDragWidth, Math.max(0, closingDelta));
    const dragPosition =
      closingDelta >= 0 ? this.pxClosed : -dampenedOverdrag(-closingDelta);
    const translation =
      this._swipeMenuOrigin === "right" ? dragPosition : -dragPosition;
    const cloakElement = document.querySelector(".header-cloak");

    this._drawerDragPanel.animate(
      [{ transform: `translate3d(${translation}px, 0, 0)` }],
      {
        duration: 0,
        fill: "forwards",
      }
    );
    cloakElement?.animate?.(
      [
        {
          opacity:
            (this._drawerDragWidth - this.pxClosed) / this._drawerDragWidth,
        },
      ],
      { duration: 0, fill: "forwards" }
    );
  }

  @bind
  onDrawerDragEnd(_event, dragInfo) {
    const panel = this._drawerDragPanel;
    if (!panel) {
      return;
    }

    const animationEvent = {
      deltaX: dragInfo.delta.x,
      velocityX: this._drawerVelocityX,
    };

    if (!dragInfo.moved && this._drawerDragStartedOnCloak) {
      this._animateClosing(null, panel, this._swipeMenuOrigin);
      scrollLock(false);
    } else if (
      this._drawerDragAxis === "horizontal" &&
      this.#shouldCloseDrawer(animationEvent)
    ) {
      this._animateClosing(animationEvent, panel, this._swipeMenuOrigin);
      scrollLock(false);
    } else {
      this._animateOpening(panel, animationEvent);
    }

    this.#resetDrawerDrag();
  }

  @bind
  onDrawerDragCancel() {
    if (this._drawerDragPanel) {
      this._animateOpening(this._drawerDragPanel);
    }
    this.#resetDrawerDrag();
  }

  #updateDrawerVelocity(event) {
    const elapsed = event.timeStamp - this._drawerLastTime;
    if (elapsed > 0) {
      this._drawerVelocityX = (event.clientX - this._drawerLastX) / elapsed;
    }
    this._drawerLastX = event.clientX;
    this._drawerLastTime = event.timeStamp;
  }

  #shouldCloseDrawer({ deltaX, velocityX }) {
    const direction = this._swipeMenuOrigin === "right" ? 1 : -1;
    const closingDistance = deltaX * direction;
    const closingVelocity = velocityX * direction;

    return (
      closingVelocity >= DRAWER_CLOSE_VELOCITY_THRESHOLD ||
      closingDistance >= this._drawerDragWidth * DRAWER_CLOSE_DISTANCE_RATIO
    );
  }

  #unlockDrawerDrag() {
    if (this._drawerDragPanel) {
      scrollLock(false, this._drawerDragPanel.querySelector(".panel-body"));
    }
  }

  #resetDrawerDrag() {
    this.#unlockDrawerDrag();
    this._drawerDragPanel = null;
    this._drawerDragAxis = null;
    this._drawerDragStartedOnCloak = false;
    this._drawerDragWidth = PANEL_WIDTH;
    this._drawerLastX = null;
    this._drawerLastTime = null;
    this._drawerVelocityX = 0;
  }

  #syncDrawerGestures(panel, cloakElement) {
    const surfaces = new Set(
      this.site.mobileView ? [panel, cloakElement].filter(Boolean) : []
    );

    for (const [surface, cleanup] of this._drawerGestureCleanups) {
      if (!surfaces.has(surface)) {
        cleanup();
        this._drawerGestureCleanups.delete(surface);
      }
    }

    for (const surface of surfaces) {
      if (this._drawerGestureCleanups.has(surface)) {
        continue;
      }

      const cleanup = registerPointerDrag(surface, () => ({
        onDragStart: this.onDrawerDragStart,
        onDrag: this.onDrawerDrag,
        onDragEnd: this.onDrawerDragEnd,
        onDragCancel: this.onDrawerDragCancel,
        threshold: 5,
        touchAction: "pan-y",
      }));
      this._drawerGestureCleanups.set(surface, cleanup);
    }
  }

  #clearDrawerGestures() {
    for (const cleanup of this._drawerGestureCleanups.values()) {
      cleanup();
    }
    this._drawerGestureCleanups.clear();
  }

  <template>
    <div
      class={{dConcatClass
        (unless this.slideInMode "drop-down-mode")
        "d-header-wrap"
      }}
      {{didInsert this.setupHeader}}
    >
      {{#if this.showImpersonationNotice}}
        <ImpersonationNotice />
      {{/if}}
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
