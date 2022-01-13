import PanEvents, {
  SWIPE_DISTANCE_THRESHOLD,
  SWIPE_VELOCITY_THRESHOLD,
} from "discourse/mixins/pan-events";
import { cancel, later, schedule } from "@ember/runloop";
import Docking from "discourse/mixins/docking";
import MountWidget from "discourse/components/mount-widget";
import ItsATrap from "@discourse/itsatrap";
import RerenderOnDoNotDisturbChange from "discourse/mixins/rerender-on-do-not-disturb-change";
import { headerOffset } from "discourse/lib/offset-calculator";
import { observes } from "discourse-common/utils/decorators";
import { topicTitleDecorators } from "discourse/components/topic-title";

const SiteHeaderComponent = MountWidget.extend(
  Docking,
  PanEvents,
  RerenderOnDoNotDisturbChange,
  {
    widget: "header",
    docAt: null,
    dockedHeader: null,
    _animate: false,
    _isPanning: false,
    _panMenuOrigin: "right",
    _panMenuOffset: 0,
    _scheduledRemoveAnimate: null,
    _topic: null,
    _itsatrap: null,

    @observes(
      "currentUser.unread_notifications",
      "currentUser.unread_high_priority_notifications",
      "currentUser.reviewable_count",
      "session.defaultColorSchemeIsDark",
      "session.darkModeAvailable"
    )
    notificationsChanged() {
      this.queueRerender();
    },

    _animateOpening(panel) {
      const headerCloak = document.querySelector(".header-cloak");
      panel.classList.add("animate");
      headerCloak.classList.add("animate");
      this._scheduledRemoveAnimate = later(() => {
        panel.classList.remove("animate");
        headerCloak.classList.remove("animate");
      }, 200);
      panel.style.setProperty("--offset", 0);
      headerCloak.style.setProperty("--opacity", 0.5);
      this._panMenuOffset = 0;
    },

    _animateClosing(panel, menuOrigin) {
      const windowWidth = document.body.offsetWidth;
      this._animate = true;
      const headerCloak = document.querySelector(".header-cloak");
      panel.classList.add("animate");
      headerCloak.classList.add("animate");
      const offsetDirection = menuOrigin === "left" ? -1 : 1;
      panel.style.setProperty("--offset", `${offsetDirection * windowWidth}px`);
      headerCloak.style.setProperty("--opacity", 0);
      this._scheduledRemoveAnimate = later(() => {
        panel.classList.remove("animate");
        headerCloak.classList.remove("animate");
        schedule("afterRender", () => {
          this.eventDispatched("dom:clean", "header");
          this._panMenuOffset = 0;
        });
      }, 200);
    },

    _isRTL() {
      return document.querySelector("html").classList["direction"] === "rtl";
    },

    _leftMenuClass() {
      return this._isRTL() ? "user-menu" : "hamburger-panel";
    },

    _leftMenuAction() {
      return this._isRTL() ? "toggleUserMenu" : "toggleHamburger";
    },

    _rightMenuAction() {
      return this._isRTL() ? "toggleHamburger" : "toggleUserMenu";
    },

    _handlePanDone(event) {
      const menuPanels = document.querySelectorAll(".menu-panel");
      const menuOrigin = this._panMenuOrigin;
      menuPanels.forEach((panel) => {
        panel.classList.remove("moving");
        if (this._shouldMenuClose(event, menuOrigin)) {
          this._animateClosing(panel, menuOrigin);
        } else {
          this._animateOpening(panel);
        }
      });
    },

    _shouldMenuClose(e, menuOrigin) {
      // menu should close after a pan either:
      // if a user moved the panel closed past a threshold and away and is NOT swiping back open
      // if a user swiped to close fast enough regardless of distance
      if (menuOrigin === "right") {
        return (
          (e.deltaX > SWIPE_DISTANCE_THRESHOLD &&
            e.velocityX > -SWIPE_VELOCITY_THRESHOLD) ||
          e.velocityX > 0
        );
      } else {
        return (
          (e.deltaX < -SWIPE_DISTANCE_THRESHOLD &&
            e.velocityX < SWIPE_VELOCITY_THRESHOLD) ||
          e.velocityX < 0
        );
      }
    },

    panStart(e) {
      const center = e.center;
      const panOverValidElement = document
        .elementsFromPoint(center.x, center.y)
        .some(
          (ele) =>
            ele.classList.contains("panel-body") ||
            ele.classList.contains("header-cloak")
        );
      if (
        panOverValidElement &&
        (e.direction === "left" || e.direction === "right")
      ) {
        e.originalEvent.preventDefault();
        this._isPanning = true;
        const panel = document.querySelector(".menu-panel");
        if (panel) {
          panel.classList.add("moving");
        }
      } else {
        this._isPanning = false;
      }
    },

    panEnd(e) {
      if (!this._isPanning) {
        return;
      }
      this._isPanning = false;
      this._handlePanDone(e);
    },

    panMove(e) {
      if (!this._isPanning) {
        return;
      }
      const panel = document.querySelector(".menu-panel");
      const headerCloak = document.querySelector(".header-cloak");
      if (this._panMenuOrigin === "right") {
        const pxClosed = Math.min(0, -e.deltaX + this._panMenuOffset);
        panel.style.setProperty("--offset", `${-pxClosed}px`);
        headerCloak.style.setProperty(
          "--opacity",
          Math.min(0.5, (300 + pxClosed) / 600)
        );
      } else {
        const pxClosed = Math.min(0, e.deltaX + this._panMenuOffset);
        panel.style.setProperty("--offset", `${pxClosed}px`);
        headerCloak.style.setProperty(
          "--opacity",
          Math.min(0.5, (300 + pxClosed) / 600)
        );
      }
    },

    dockCheck() {
      const header = document.querySelector("header.d-header");

      if (this.docAt === null) {
        if (!header) {
          return;
        }
        this.docAt = header.offsetTop;
      }

      const headerRect = header.getBoundingClientRect();
      let headerOffsetCalc = headerRect.top + headerRect.height;

      if (window.scrollY < 0) {
        headerOffsetCalc += window.scrollY;
      }

      const newValue = `${headerOffsetCalc}px`;
      if (newValue !== this.currentHeaderOffsetValue) {
        this.currentHeaderOffsetValue = newValue;
        document.documentElement.style.setProperty("--header-offset", newValue);
      }

      if (window.pageYOffset >= this.docAt) {
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

      this.dispatch("notifications:changed", "user-notifications");
      this.dispatch("header:keyboard-trigger", "header");
      this.dispatch("user-menu:navigation", "user-menu");

      this.appEvents.on("dom:clean", this, "_cleanDom");

      if (
        this.currentUser &&
        !this.get("currentUser.read_first_notification")
      ) {
        document.body.classList.add("unread-first-notification");
      }

      // Allow first notification to be dismissed on a click anywhere
      if (
        this.currentUser &&
        !this.get("currentUser.read_first_notification") &&
        !this.get("currentUser.enforcedSecondFactor")
      ) {
        this._dismissFirstNotification = (e) => {
          if (document.body.classList.contains("unread-first-notification")) {
            document.body.classList.remove("unread-first-notification");
          }
          if (
            !e.target.closest("#current-user") &&
            !e.target.closest(".ring-backdrop") &&
            this.currentUser &&
            !this.get("currentUser.read_first_notification") &&
            !this.get("currentUser.enforcedSecondFactor")
          ) {
            this.eventDispatched(
              "header:dismiss-first-notification-mask",
              "header"
            );
          }
        };
        document.addEventListener("click", this._dismissFirstNotification, {
          once: true,
        });
      }

      const header = document.querySelector("header.d-header");
      this._itsatrap = new ItsATrap(header);
      this._itsatrap.bind(["right", "left"], (e) => {
        const activeTab = document.querySelector(".glyphs .menu-link.active");

        if (activeTab) {
          let focusedTab = document.activeElement;
          if (!focusedTab.dataset.tabNumber) {
            focusedTab = activeTab;
          }

          this.appEvents.trigger("user-menu:navigation", {
            key: e.key,
            tabNumber: Number(focusedTab.dataset.tabNumber),
          });
        }
      });
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

      cancel(this._scheduledRemoveAnimate);

      this._itsatrap?.destroy();
      this._itsatrap = null;

      document.removeEventListener("click", this._dismissFirstNotification);
    },

    buildArgs() {
      return {
        topic: this._topic,
        canSignUp: this.canSignUp,
      };
    },

    afterRender() {
      const headerTitle = document.querySelector(".header-title .topic-link");
      if (headerTitle && this._topic) {
        topicTitleDecorators.forEach((cb) =>
          cb(this._topic, headerTitle, "header-title")
        );
      }

      const menuPanels = document.querySelectorAll(".menu-panel");
      if (menuPanels.length === 0) {
        if (this.site.mobileView) {
          this._animate = true;
        }
        return;
      }

      const windowWidth = document.body.offsetWidth;
      const viewMode = this.site.mobileView ? "slide-in" : "drop-down";

      menuPanels.forEach((panel) => {
        const headerCloak = document.querySelector(".header-cloak");
        let width = parseInt(panel.getAttribute("data-max-width"), 10) || 300;
        if (windowWidth - width < 50) {
          width = windowWidth - 50;
        }
        if (this._panMenuOffset) {
          this._panMenuOffset = -width;
        }

        panel.classList.remove("drop-down");
        panel.classList.remove("slide-in");
        panel.classList.add(viewMode);
        if (this._animate || this._panMenuOffset !== 0) {
          if (
            this.site.mobileView &&
            panel.parentElement.classList.contains(this._leftMenuClass())
          ) {
            this._panMenuOrigin = "left";
            panel.style.setProperty("--offset", `${-windowWidth}px`);
          } else {
            this._panMenuOrigin = "right";
            panel.style.setProperty("--offset", `${windowWidth}px`);
          }
          headerCloak.style.setProperty("--opacity", 0);
        }

        const panelBody = panel.querySelector(".panel-body");

        // We use a mutationObserver to check for style changes, so it's important
        // we don't set it if it doesn't change. Same goes for the panelBody!

        if (viewMode === "drop-down") {
          const buttonPanel = document.querySelectorAll("header ul.icons");
          if (buttonPanel.length === 0) {
            return;
          }

          // These values need to be set here, not in the css file - this is to deal with the
          // possibility of the window being resized and the menu changing from .slide-in to .drop-down.
          if (panel.style.top !== "100%" || panel.style.height !== "auto") {
            panel.style.setProperty("top", "100%");
            panel.style.setProperty("height", "auto");
          }

          document.body.classList.add("drop-down-mode");
        } else {
          if (this.site.mobileView) {
            headerCloak.style.display = "block";
          }

          const menuTop = this.site.mobileView ? headerTop() : headerOffset();

          const winHeightOffset = 16;
          let initialWinHeight = window.innerHeight;
          const winHeight = initialWinHeight - winHeightOffset;

          let height;
          if (this.site.mobileView) {
            height = winHeight - menuTop;
          }

          const isIPadApp = document.body.classList.contains("footer-nav-ipad"),
            heightProp = isIPadApp ? "max-height" : "height",
            iPadOffset = 10;

          if (isIPadApp) {
            height = winHeight - menuTop - iPadOffset;
          }

          if (panelBody.style.height !== "100%") {
            panelBody.style.setProperty("height", "100%");
          }
          if (
            panel.style.top !== `${menuTop}px` ||
            panel.style[heightProp] !== `${height}px`
          ) {
            panel.style.top = `${menuTop}px`;
            panel.style.setProperty(heightProp, `${height}px`);
            if (headerCloak) {
              headerCloak.style.top = `${menuTop}px`;
            }
          }
          document.body.classList.remove("drop-down-mode");
        }

        panel.style.setProperty("width", `${width}px`);
        if (this._animate) {
          this._animateOpening(panel);
        }
        this._animate = false;
      });
    },
  }
);

export default SiteHeaderComponent.extend({
  classNames: ["d-header-wrap"],
});

export function headerTop() {
  const header = document.querySelector("header.d-header");
  const headerOffsetTop = header.offsetTop ? header.offsetTop : 0;
  return headerOffsetTop - document.body.scrollTop;
}
