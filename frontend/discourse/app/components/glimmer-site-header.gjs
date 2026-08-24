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
const DRAWER_DRAG_THRESHOLD = 5;
const HAMBURGER_BUTTON_ID = "toggle-hamburger-menu";
const USER_BUTTON_ID = "toggle-current-user";
const DRAWER_TAP_SLOP = 10;
const DRAWER_VELOCITY_EXPIRY_MS = 100;

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
  _drawerDrag;
  _drawerAnimations = [];
  _drawerCloseGeneration = 0;
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
        let finalPosition = this.#drawerWidth(panel);
        this._swipeMenuOrigin = "right";
        if (this.slideInMode && this.#isLeftMenu(panel)) {
          this._swipeMenuOrigin = "left";
          finalPosition = -finalPosition;
        }
        animationFinished = this.#driveDrawer(
          panel,
          "transform",
          [{ transform: `translate3d(${finalPosition}px, 0, 0)` }],
          { fill: "forwards" }
        ).finished;

        waitForPromise(animationFinished.catch(() => {}));

        if (cloakElement) {
          this.#driveDrawer(cloakElement, "opacity", [{ opacity: 0 }], {
            fill: "forwards",
          });
          cloakElement.style.display = "block";
        }

        animationFinished
          .then(() => {
            if (isTesting()) {
              this._animateOpening(panel);
            } else {
              discourseLater(() => this._animateOpening(panel));
            }
          })
          .catch(() => {});
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
      this.#driveDrawer(
        panel,
        "transform",
        [{ transform: `translate3d(0, 0, 0)` }],
        timing
      ).finished,
    ];
    if (cloakElement) {
      cloakElement.style.display = "block";
      animations.push(
        this.#driveDrawer(cloakElement, "opacity", [{ opacity: 1 }], timing)
          .finished
      );
    }

    waitForPromise(Promise.all(animations).catch(() => {}));
    this.pxClosed = null;
  }

  @bind
  _animateClosing(event, panel, menuOrigin) {
    this._animate = true;
    const cloakElement = document.querySelector(".header-cloak");
    const panelWidth = this.#drawerWidth(panel);
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
      this.#driveDrawer(
        panel,
        "transform",
        [{ transform: `translate3d(${endPosition}px, 0, 0)` }],
        timing
      ).finished,
    ];
    if (cloakElement) {
      animations.push(
        this.#driveDrawer(cloakElement, "opacity", [{ opacity: 0 }], timing)
          .finished
      );
    }

    const generation = ++this._drawerCloseGeneration;
    const closingFinished = Promise.all(animations)
      .catch(() => {})
      .then(() => {
        if (
          generation !== this._drawerCloseGeneration ||
          !panel.isConnected ||
          this.isDestroying ||
          this.isDestroyed
        ) {
          return;
        }

        this.#clearDrawerGestures();

        if (cloakElement) {
          cloakElement.style.display = "none";
        }

        scrollLock(false);

        if (this.header.hamburgerVisible || this.header.userVisible) {
          const toggleId = this.header.hamburgerVisible
            ? HAMBURGER_BUTTON_ID
            : USER_BUTTON_ID;

          this.header.hamburgerVisible = false;
          this.header.userVisible = false;
          document.getElementById(toggleId)?.focus();
        }
      });

    waitForPromise(closingFinished);
    this.pxClosed = null;
  }

  @bind
  onDrawerDragStart(event) {
    const target = event.target;
    if (!this.slideInMode || !(target instanceof Element)) {
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

    if (cloakAtPointer) {
      event.stopPropagation();
    }

    // refusing before the stopPropagation above would let the outside-press
    // handler dismiss the drawer mid-gesture
    if (this._drawerDrag) {
      return false;
    }

    this._drawerCloseGeneration++;
    this._swipeMenuOrigin = this.#isLeftMenu(panel) ? "left" : "right";

    const startClosed = this.#stopDrawerSettle(panel);

    this._drawerDrag = {
      axis: null,
      lastTime: event.timeStamp,
      lastX: event.clientX,
      panel,
      pointerId: event.pointerId,
      cloak: document.querySelector(".header-cloak"),
      scroller: panel.querySelector(".panel-body"),
      scrollerLocked: false,
      startClosed,
      startedOnCloak: Boolean(cloakAtPointer),
      velocityX: 0,
      width: this.#drawerWidth(panel),
    };
    this.pxClosed = startClosed;
  }

  #driveDrawer(element, property, keyframes, timing) {
    const animation = element.animate(keyframes, timing);
    this._drawerAnimations.push({ animation, property });
    return animation;
  }

  #stopDrawerSettle(panel) {
    this.#stopDrawerAnimations();

    const { transform } = window.getComputedStyle(panel);
    const translateX =
      transform === "none" ? 0 : new DOMMatrixReadOnly(transform).m41;

    return Math.max(
      0,
      Math.min(translateX * this.#closingDirection(), this.#drawerWidth(panel))
    );
  }

  // a cancelled fill-forwards animation reverts its element, so pin what is
  // on screen first
  #stopDrawerAnimations() {
    for (const { animation, property } of this._drawerAnimations) {
      const target = animation.effect?.target;
      if (target?.isConnected) {
        target.style[property] = window.getComputedStyle(target)[property];
      }
      animation.cancel();
    }
    this._drawerAnimations = [];
  }

  #drawerWidth(panel) {
    return panel.getBoundingClientRect().width || PANEL_WIDTH;
  }

  @bind
  onDrawerDrag(event, dragInfo) {
    const drawerDrag = this._drawerDrag;
    if (drawerDrag?.pointerId !== event.pointerId) {
      return;
    }

    if (!drawerDrag.axis) {
      drawerDrag.axis =
        Math.abs(dragInfo.delta.x) >= Math.abs(dragInfo.delta.y)
          ? "horizontal"
          : "vertical";

      if (drawerDrag.axis === "horizontal" && drawerDrag.scroller) {
        scrollLock(true, drawerDrag.scroller);
        drawerDrag.scrollerLocked = true;
      }
    }

    if (drawerDrag.axis !== "horizontal") {
      return;
    }

    this.#updateDrawerVelocity(event);

    const closingDelta = this.#closingTravel(dragInfo.delta.x);
    this.pxClosed = Math.min(drawerDrag.width, Math.max(0, closingDelta));
    const dragPosition =
      closingDelta >= 0 ? this.pxClosed : -dampenedOverdrag(-closingDelta);
    const translation =
      this._swipeMenuOrigin === "right" ? dragPosition : -dragPosition;

    // Avoid allocating an Animation per pointermove.
    drawerDrag.panel.style.transform = `translate3d(${translation}px, 0, 0)`;
    if (drawerDrag.cloak) {
      drawerDrag.cloak.style.opacity =
        (drawerDrag.width - this.pxClosed) / drawerDrag.width;
    }
  }

  @bind
  onDrawerDragEnd(event, dragInfo) {
    const drawerDrag = this._drawerDrag;
    if (drawerDrag?.pointerId !== event.pointerId) {
      return;
    }

    const animationEvent = {
      deltaX: dragInfo.delta.x,
      velocityX: this.#releaseVelocity(event),
    };

    if (this.#shouldCloseDrawer(animationEvent)) {
      this._animateClosing(
        animationEvent,
        drawerDrag.panel,
        this._swipeMenuOrigin
      );
    } else {
      this._animateOpening(drawerDrag.panel, animationEvent);
    }

    this.#resetDrawerDrag();
  }

  @bind
  onDrawerDragCancel(event, dragInfo) {
    const drawerDrag = this._drawerDrag;
    if (drawerDrag?.pointerId !== event.pointerId) {
      return;
    }

    if (drawerDrag.startedOnCloak) {
      const cancelEvent = { deltaX: dragInfo.delta.x, velocityX: 0 };

      if (this.#shouldCloseDrawer(cancelEvent)) {
        this._animateClosing(
          cancelEvent,
          drawerDrag.panel,
          this._swipeMenuOrigin
        );
      } else {
        this._animateOpening(drawerDrag.panel);
      }
    } else if (drawerDrag.axis === "horizontal") {
      this._animateOpening(drawerDrag.panel);
    }

    this.#resetDrawerDrag();
  }

  #updateDrawerVelocity(event) {
    const drawerDrag = this._drawerDrag;
    const elapsed = event.timeStamp - drawerDrag.lastTime;
    drawerDrag.velocityX =
      elapsed > 0 ? (event.clientX - drawerDrag.lastX) / elapsed : 0;
    drawerDrag.lastX = event.clientX;
    drawerDrag.lastTime = event.timeStamp;
  }

  #releaseVelocity(event) {
    const drawerDrag = this._drawerDrag;
    const idleMs = event.timeStamp - drawerDrag.lastTime;
    return idleMs > DRAWER_VELOCITY_EXPIRY_MS ? 0 : drawerDrag.velocityX;
  }

  #isLeftMenu(panel) {
    return Boolean(panel.closest(`.${this.leftMenuClass}`));
  }

  #closingTravel(deltaX) {
    return (
      (this._drawerDrag?.startClosed ?? 0) + deltaX * this.#closingDirection()
    );
  }

  #closingDirection() {
    return this._swipeMenuOrigin === "right" ? 1 : -1;
  }

  #shouldCloseDrawer({ deltaX, velocityX }) {
    const drawerDrag = this._drawerDrag;
    const direction = this.#closingDirection();
    const closingDistance = this.#closingTravel(deltaX);

    if (drawerDrag.startedOnCloak) {
      return closingDistance > -DRAWER_TAP_SLOP;
    }

    if (drawerDrag.axis !== "horizontal") {
      return false;
    }

    const flickedClosed =
      closingDistance > 0 &&
      velocityX * direction >= DRAWER_CLOSE_VELOCITY_THRESHOLD;

    return (
      flickedClosed ||
      closingDistance >= drawerDrag.width * DRAWER_CLOSE_DISTANCE_RATIO
    );
  }

  #resetDrawerDrag() {
    if (this._drawerDrag?.scrollerLocked) {
      scrollLock(false, this._drawerDrag.scroller);
    }
    this._drawerDrag = null;
  }

  #syncDrawerGestures(panel, cloakElement) {
    const surfaces = new Set(
      this.slideInMode ? [panel, cloakElement].filter(Boolean) : []
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

      const isPanel = surface === panel;

      const cleanup = registerPointerDrag(surface, () => ({
        onDragStart: this.onDrawerDragStart,
        onDrag: this.onDrawerDrag,
        onDragEnd: this.onDrawerDragEnd,
        onDragCancel: this.onDrawerDragCancel,
        threshold: DRAWER_DRAG_THRESHOLD,
        touchAction: "pan-y",
        preservePress: isPanel,
      }));
      this._drawerGestureCleanups.set(surface, cleanup);
    }
  }

  #clearDrawerGestures() {
    // teardown fires no terminal callback, so the gesture state is dropped here
    this.#resetDrawerDrag();
    for (const cleanup of this._drawerGestureCleanups.values()) {
      cleanup();
    }
    this._drawerGestureCleanups.clear();

    this.#stopDrawerAnimations();
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
