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
import dSwipe from "discourse/ui-kit/modifiers/d-swipe";
import Header from "./header";
import ImpersonationNotice from "./impersonation-notice";

let _menuPanelClassesToForceDropdown = [];
const PANEL_WIDTH_FALLBACK = 340;
const DEBOUNCE_HEADER_DELAY = 10;
const DRAWER_SETTLE_EASING = "cubic-bezier(0.32, 0.72, 0, 1)";
const DRAWER_CLOSE_DISTANCE_RATIO = 0.25;
const DRAWER_CLOSE_VELOCITY_THRESHOLD = 0.4;
const HAMBURGER_BUTTON_ID = "toggle-hamburger-menu";
const USER_BUTTON_ID = "toggle-current-user";

export default class GlimmerSiteHeader extends Component {
  @service appEvents;
  @service currentUser;
  @service site;
  @service header;

  headerElement;

  _animate = false;
  _headerWrap;
  _mainOutletWrapper;
  _drawerOrigin;
  _drawerPress;
  _drawerSwipe;
  _drawerAnimations = [];
  _drawerTransitionId = 0;
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
    this._headerWrap?.removeEventListener(
      "pointerdown",
      this.onDrawerPointerDown
    );
    this._resizeObserver.disconnect();
    cancel(this.recalculationTimer);
    this.#resetDrawerSwipe();
    this.#freezeDrawerAnimations();
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
      this._headerWrap.addEventListener(
        "pointerdown",
        this.onDrawerPointerDown
      );
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
      this.#resetDrawerSwipe();
      this.#freezeDrawerAnimations();
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
        this._drawerOrigin = this.#isLeftMenu(panel) ? "left" : "right";
        const finalPosition =
          this.#drawerWidth(panel) * this.#closingDirection();
        panel.style.transform = `translate3d(${finalPosition}px, 0, 0)`;

        if (cloakElement) {
          cloakElement.style.opacity = 0;
          cloakElement.style.display = "block";
        }

        if (isTesting()) {
          this._animateOpening(panel);
        } else {
          discourseLater(() => this._animateOpening(panel));
        }
      }

      this._animate = false;
    });
  }

  @bind
  _animateOpening(panel) {
    this._drawerTransitionId++;
    waitForPromise(this.#settleDrawer(panel, false).finished);
  }

  @bind
  _animateClosing(panel, menuOrigin) {
    this._animate = true;
    const transitionId = ++this._drawerTransitionId;
    const { cloak, finished } = this.#settleDrawer(panel, true, menuOrigin);
    const closingFinished = finished.then(() => {
      if (
        transitionId !== this._drawerTransitionId ||
        !panel.isConnected ||
        this.isDestroying ||
        this.isDestroyed
      ) {
        return;
      }

      this.#resetDrawerSwipe();
      this.#freezeDrawerAnimations();
      if (cloak) {
        cloak.style.display = "none";
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
  }

  @bind
  onSwipePress(event) {
    this.#beginDrawerPress(event.target);
  }

  @bind
  onSwipeRelease() {
    const press = this._drawerPress;
    if (!press) {
      return;
    }

    this._drawerPress = null;
    if (press.startedOnCloak) {
      this._animateClosing(press.panel, this._drawerOrigin);
    } else if (press.startClosed > 0) {
      this._animateOpening(press.panel);
    }
  }

  @bind
  onDrawerPointerDown(event) {
    if (
      !this.slideInMode ||
      !(event.target instanceof Element) ||
      !event.target.closest(".header-cloak")
    ) {
      return;
    }

    event.stopPropagation();
    if (event.pointerType !== "touch") {
      const press = this.#beginDrawerPress(event.target);
      if (press) {
        this._drawerPress = null;
        this._animateClosing(press.panel, this._drawerOrigin);
      }
    }
  }

  @bind
  onSwipeStart(swipeEvent, fullEvent) {
    const press = this._drawerPress;
    const horizontal =
      swipeEvent.direction === "left" || swipeEvent.direction === "right";

    if (!press || (!press.startedOnCloak && !horizontal)) {
      fullEvent.preventDefault();
      return;
    }

    swipeEvent.originalEvent.preventDefault();

    const scroller = press.panel.querySelector(".panel-body");
    this._drawerSwipe = {
      ...press,
      horizontal,
      scroller,
      scrollerLocked: false,
    };
    this._drawerPress = null;

    if (horizontal && scroller) {
      scrollLock(true, scroller);
      this._drawerSwipe.scrollerLocked = true;
    }
    if (horizontal) {
      this.onSwipe(swipeEvent);
    }
  }

  @bind
  onSwipeEnd(swipeEvent) {
    const swipe = this._drawerSwipe;
    if (!swipe) {
      return;
    }

    const closes = this.#shouldCloseDrawer(
      swipe,
      swipeEvent.deltaX,
      swipeEvent.velocityX
    );
    this.#resetDrawerSwipe();

    if (closes) {
      this._animateClosing(swipe.panel, this._drawerOrigin);
    } else {
      this._animateOpening(swipe.panel);
    }
  }

  @bind
  onSwipeCancel() {
    const swipe = this._drawerSwipe;
    const press = this._drawerPress;
    this.#resetDrawerSwipe();

    if (swipe?.startedOnCloak || press?.startedOnCloak) {
      this._animateClosing((swipe ?? press).panel, this._drawerOrigin);
    } else if (swipe || press?.startClosed > 0) {
      this._animateOpening((swipe ?? press).panel);
    }
  }

  @bind
  onSwipe(swipeEvent) {
    const swipe = this._drawerSwipe;
    if (!swipe?.horizontal) {
      return;
    }

    const closingTravel =
      swipe.startClosed + swipeEvent.deltaX * this.#closingDirection();
    const closed = Math.min(swipe.width, Math.max(0, closingTravel));
    const position =
      closingTravel >= 0 ? closed : -dampenedOverdrag(-closingTravel);
    const translation = position * this.#closingDirection();

    swipe.panel.style.transform = `translate3d(${translation}px, 0, 0)`;
    if (swipe.cloak) {
      swipe.cloak.style.opacity = (swipe.width - closed) / swipe.width;
    }
  }

  #beginDrawerPress(target) {
    if (!this.slideInMode || !(target instanceof Element)) {
      return;
    }

    const panelAtPointer = target.closest(".menu-panel.slide-in");
    const cloakAtPointer = target.closest(".header-cloak");
    if (!panelAtPointer && !cloakAtPointer) {
      return;
    }
    if (target.closest("input, textarea, select, [contenteditable='true']")) {
      return;
    }

    const panel =
      panelAtPointer ?? document.querySelector(".menu-panel.slide-in");
    if (!panel) {
      return;
    }

    this._drawerTransitionId++;
    this._animate = false;
    this._drawerOrigin = this.#isLeftMenu(panel) ? "left" : "right";
    const press = {
      cloak: document.querySelector(".header-cloak"),
      panel,
      startClosed: this.#catchDrawer(panel),
      startedOnCloak: Boolean(cloakAtPointer),
      width: this.#drawerWidth(panel),
    };
    this._drawerPress = press;
    return press;
  }

  #shouldCloseDrawer(swipe, deltaX, velocityX) {
    const closingDistance =
      swipe.startClosed + deltaX * this.#closingDirection();

    if (swipe.startedOnCloak) {
      return closingDistance > -swipe.width * DRAWER_CLOSE_DISTANCE_RATIO;
    }
    if (!swipe.horizontal) {
      return false;
    }

    const flickedClosed =
      closingDistance > 0 &&
      velocityX * this.#closingDirection() >= DRAWER_CLOSE_VELOCITY_THRESHOLD;
    return (
      flickedClosed ||
      closingDistance >= swipe.width * DRAWER_CLOSE_DISTANCE_RATIO
    );
  }

  #settleDrawer(panel, closes, origin = this._drawerOrigin) {
    this.#freezeDrawerAnimations();
    const cloak = document.querySelector(".header-cloak");
    const timing = {
      duration: getMaxAnimationTimeMs(),
      fill: "forwards",
      easing: DRAWER_SETTLE_EASING,
    };
    const position = closes
      ? this.#drawerWidth(panel) * (origin === "right" ? 1 : -1)
      : 0;
    const animations = [
      this.#animateDrawer(
        panel,
        "transform",
        [{ transform: `translate3d(${position}px, 0, 0)` }],
        timing
      ),
    ];

    if (cloak) {
      cloak.style.display = "block";
      animations.push(
        this.#animateDrawer(
          cloak,
          "opacity",
          [{ opacity: closes ? 0 : 1 }],
          timing
        )
      );
    }

    return {
      cloak,
      finished: Promise.allSettled(
        animations.map((animation) => animation.finished)
      ),
    };
  }

  #animateDrawer(element, property, keyframes, timing) {
    const animation = element.animate(keyframes, timing);
    this._drawerAnimations.push({ animation, property });
    return animation;
  }

  #catchDrawer(panel) {
    this.#freezeDrawerAnimations();
    const { transform } = window.getComputedStyle(panel);
    const translateX =
      transform === "none" ? 0 : new DOMMatrixReadOnly(transform).m41;
    return Math.max(
      0,
      Math.min(translateX * this.#closingDirection(), this.#drawerWidth(panel))
    );
  }

  #freezeDrawerAnimations() {
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
    return panel.offsetWidth || PANEL_WIDTH_FALLBACK;
  }

  #isLeftMenu(panel) {
    return Boolean(panel.closest(`.${this.leftMenuClass}`));
  }

  #closingDirection() {
    return this._drawerOrigin === "right" ? 1 : -1;
  }

  #resetDrawerSwipe() {
    if (this._drawerSwipe?.scrollerLocked) {
      scrollLock(false, this._drawerSwipe.scroller);
    }
    this._drawerPress = null;
    this._drawerSwipe = null;
  }

  <template>
    <div
      class={{dConcatClass
        (unless this.slideInMode "drop-down-mode")
        "d-header-wrap"
      }}
      {{didInsert this.setupHeader}}
      {{dSwipe
        onDidPress=this.onSwipePress
        onDidRelease=this.onSwipeRelease
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
