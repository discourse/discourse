import MountWidget from "discourse/components/mount-widget";
import { observes } from "ember-addons/ember-computed-decorators";
import Docking from "discourse/mixins/docking";
import PanEvents, {
  SWIPE_VELOCITY,
  SWIPE_DISTANCE_THRESHOLD,
  SWIPE_VELOCITY_THRESHOLD
} from "discourse/mixins/pan-events";

const _flagProperties = [];
function addFlagProperty(prop) {
  _flagProperties.pushObject(prop);
}

const PANEL_BODY_MARGIN = 30;

//android supports pulling in from the screen edges
const SCREEN_EDGE_MARGIN = 30;
const SCREEN_OFFSET = 300;

const SiteHeaderComponent = MountWidget.extend(Docking, PanEvents, {
  widget: "header",
  docAt: null,
  dockedHeader: null,
  _animate: false,
  _isPanning: false,
  _panMenuOrigin: "right",
  _panMenuOffset: 0,
  _scheduledMovingAnimation: null,
  _scheduledRemoveAnimate: null,
  _topic: null,

  @observes(
    "currentUser.unread_notifications",
    "currentUser.unread_private_messages"
  )
  notificationsChanged() {
    this.queueRerender();
  },

  _animateOpening($panel) {
    $panel.css({ right: "", left: "" });
    this._panMenuOffset = 0;
  },

  _animateClosing($panel, menuOrigin, windowWidth) {
    $panel.css(menuOrigin, -windowWidth);
    this._animate = true;
    Ember.run.schedule("afterRender", () => {
      this.eventDispatched("dom:clean", "header");
      this._panMenuOffset = 0;
    });
  },

  _isRTL() {
    return $("html").css("direction") === "rtl";
  },

  _leftMenuClass() {
    return this._isRTL() ? ".user-menu" : ".hamburger-panel";
  },

  _leftMenuAction() {
    return this._isRTL() ? "toggleUserMenu" : "toggleHamburger";
  },

  _rightMenuAction() {
    return this._isRTL() ? "toggleHamburger" : "toggleUserMenu";
  },

  _handlePanDone(offset, event) {
    const $window = $(window);
    const windowWidth = parseInt($window.width());
    const $menuPanels = $(".menu-panel");
    const menuOrigin = this._panMenuOrigin;
    this._shouldMenuClose(event, menuOrigin)
      ? (offset += SWIPE_VELOCITY)
      : (offset -= SWIPE_VELOCITY);
    $menuPanels.each((idx, panel) => {
      const $panel = $(panel);
      const $headerCloak = $(".header-cloak");
      $panel.css(menuOrigin, -offset);
      $headerCloak.css("opacity", Math.min(0.5, (300 - offset) / 600));
      if (offset > windowWidth) {
        this._animateClosing($panel, menuOrigin, windowWidth);
      } else if (offset <= 0) {
        this._animateOpening($panel);
      } else {
        //continue to open or close menu
        this._scheduledMovingAnimation = window.requestAnimationFrame(() =>
          this._handlePanDone(offset, event)
        );
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
    const $centeredElement = $(document.elementFromPoint(center.x, center.y));
    const $window = $(window);
    const windowWidth = parseInt($window.width());
    if (
      ($centeredElement.hasClass("panel-body") ||
        $centeredElement.hasClass("header-cloak") ||
        $centeredElement.parents(".panel-body").length) &&
      (e.direction === "left" || e.direction === "right")
    ) {
      e.originalEvent.preventDefault();
      this._isPanning = true;
    } else if (
      center.x < SCREEN_EDGE_MARGIN &&
      !this.$(".menu-panel").length &&
      e.direction === "right"
    ) {
      this._animate = false;
      this._panMenuOrigin = "left";
      this._panMenuOffset = -SCREEN_OFFSET;
      this._isPanning = true;
      $("header.d-header").removeClass("scroll-down scroll-up");
      this.eventDispatched(this._leftMenuAction(), "header");
    } else if (
      windowWidth - center.x < SCREEN_EDGE_MARGIN &&
      !this.$(".menu-panel").length &&
      e.direction === "left"
    ) {
      this._animate = false;
      this._panMenuOrigin = "right";
      this._panMenuOffset = -SCREEN_OFFSET;
      this._isPanning = true;
      $("header.d-header").removeClass("scroll-down scroll-up");
      this.eventDispatched(this._rightMenuAction(), "header");
    } else {
      this._isPanning = false;
    }
  },

  panEnd(e) {
    if (!this._isPanning) {
      return;
    }
    this._isPanning = false;
    $(".menu-panel").each((idx, panel) => {
      const $panel = $(panel);
      let offset = $panel.css("right");
      if (this._panMenuOrigin === "left") {
        offset = $panel.css("left");
      }
      offset = Math.abs(parseInt(offset, 10));
      this._handlePanDone(offset, e);
    });
  },

  panMove(e) {
    if (!this._isPanning) {
      return;
    }
    const $menuPanels = $(".menu-panel");
    $menuPanels.each((idx, panel) => {
      const $panel = $(panel);
      const $headerCloak = $(".header-cloak");
      if (this._panMenuOrigin === "right") {
        const pxClosed = Math.min(0, -e.deltaX + this._panMenuOffset);
        $panel.css("right", pxClosed);
        $headerCloak.css("opacity", Math.min(0.5, (300 + pxClosed) / 600));
      } else {
        const pxClosed = Math.min(0, e.deltaX + this._panMenuOffset);
        $panel.css("left", pxClosed);
        $headerCloak.css("opacity", Math.min(0.5, (300 + pxClosed) / 600));
      }
    });
  },

  dockCheck(info) {
    const $header = $("header.d-header");

    if (this.docAt === null) {
      if (!($header && $header.length === 1)) return;
      this.docAt = $header.offset().top;
    }

    const $body = $("body");
    const offset = info.offset();
    if (offset >= this.docAt) {
      if (!this.dockedHeader) {
        $body.addClass("docked");
        this.dockedHeader = true;
      }
    } else {
      if (this.dockedHeader) {
        $body.removeClass("docked");
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
      $("body").addClass("staff");
    }
  },

  didInsertElement() {
    this._super(...arguments);
    $(window).on("resize.discourse-menu-panel", () => this.afterRender());

    this.appEvents.on("header:show-topic", topic => this.setTopic(topic));
    this.appEvents.on("header:hide-topic", () => this.setTopic(null));

    this.dispatch("notifications:changed", "user-notifications");
    this.dispatch("header:keyboard-trigger", "header");
    this.dispatch("search-autocomplete:after-complete", "search-term");

    this.appEvents.on("dom:clean", () => {
      // For performance, only trigger a re-render if any menu panels are visible
      if (this.$(".menu-panel").length) {
        this.eventDispatched("dom:clean", "header");
      }
    });

    if (this.site.mobileView) {
      $("body")
        .on("pointerdown", e => this._panStart(e))
        .on("pointermove", e => this._panMove(e))
        .on("pointerup", e => this._panMove(e))
        .on("pointercancel", e => this._panMove(e));
    }
  },

  willDestroyElement() {
    this._super(...arguments);
    $("body").off("keydown.header");
    $(window).off("resize.discourse-menu-panel");

    this.appEvents.off("header:show-topic");
    this.appEvents.off("header:hide-topic");
    this.appEvents.off("dom:clean");

    if (this.site.mobileView) {
      $("body")
        .off("pointerdown")
        .off("pointerup")
        .off("pointermove")
        .off("pointercancel");
    }
    Ember.run.cancel(this._scheduledRemoveAnimate);
    window.cancelAnimationFrame(this._scheduledMovingAnimation);
  },

  buildArgs() {
    return {
      flagCount: _flagProperties.reduce(
        (prev, cur) => prev + (this.get(cur) || 0),
        0
      ),
      topic: this._topic,
      canSignUp: this.get("canSignUp")
    };
  },

  afterRender() {
    const $menuPanels = $(".menu-panel");
    if ($menuPanels.length === 0) {
      if (this.site.mobileView) {
        this._animate = true;
      }
      return;
    }

    const $window = $(window);
    const windowWidth = parseInt($window.width());

    const headerWidth = $("#main-outlet .container").width() || 1100;
    const remaining = parseInt((windowWidth - headerWidth) / 2);
    const viewMode = remaining < 50 ? "slide-in" : "drop-down";

    $menuPanels.each((idx, panel) => {
      const $panel = $(panel);
      const $headerCloak = $(".header-cloak");
      let width = parseInt($panel.attr("data-max-width") || 300);
      if (windowWidth - width < 50) {
        width = windowWidth - 50;
      }
      if (this._panMenuOffset) {
        this._panMenuOffset = -width;
      }

      $panel.removeClass("drop-down slide-in").addClass(viewMode);
      if (this._animate || this._panMenuOffset !== 0) {
        $headerCloak.css("opacity", 0);
        if (
          this.site.mobileView &&
          $panel.parent(this._leftMenuClass()).length > 0
        ) {
          this._panMenuOrigin = "left";
          $panel.css("left", -windowWidth);
        } else {
          this._panMenuOrigin = "right";
          $panel.css("right", -windowWidth);
        }
      }

      const $panelBody = $(".panel-body", $panel);
      // 2 pixel fudge allows for firefox subpixel sizing stuff causing scrollbar
      let contentHeight =
        parseInt($(".panel-body-contents", $panel).height()) + 2;

      // We use a mutationObserver to check for style changes, so it's important
      // we don't set it if it doesn't change. Same goes for the $panelBody!
      const style = $panel.prop("style");

      if (viewMode === "drop-down") {
        const $buttonPanel = $("header ul.icons");
        if ($buttonPanel.length === 0) {
          return;
        }

        // These values need to be set here, not in the css file - this is to deal with the
        // possibility of the window being resized and the menu changing from .slide-in to .drop-down.
        if (style.top !== "100%" || style.height !== "auto") {
          $panel.css({ top: "100%", height: "auto" });
        }

        // adjust panel height
        const fullHeight = parseInt($window.height());
        const offsetTop = $panel.offset().top;
        const scrollTop = $window.scrollTop();

        if (
          contentHeight + (offsetTop - scrollTop) + PANEL_BODY_MARGIN >
            fullHeight ||
          this.site.mobileView
        ) {
          contentHeight =
            fullHeight - (offsetTop - scrollTop) - PANEL_BODY_MARGIN;
        }
        if ($panelBody.height() !== contentHeight) {
          $panelBody.height(contentHeight);
        }
        $("body").addClass("drop-down-mode");
      } else {
        if (this.site.mobileView) {
          $headerCloak.show();
        }

        const menuTop = this.site.mobileView ? headerTop() : headerHeight();

        let height;
        const winHeightOffset = 16;
        let initialWinHeight = window.innerHeight
          ? window.innerHeight
          : $(window).height();
        const winHeight = initialWinHeight - winHeightOffset;
        if (menuTop + contentHeight < winHeight && !this.site.mobileView) {
          height = contentHeight + "px";
        } else {
          height = winHeight - menuTop;
        }

        if ($panelBody.prop("style").height !== "100%") {
          $panelBody.height("100%");
        }
        if (style.top !== menuTop + "px" || style.height !== height) {
          $panel.css({ top: menuTop + "px", height });
          $(".header-cloak").css({ top: menuTop + "px" });
        }
        $("body").removeClass("drop-down-mode");
      }

      $panel.width(width);
      if (this._animate) {
        $panel.addClass("animate");
        $headerCloak.addClass("animate");
        this._scheduledRemoveAnimate = Ember.run.later(() => {
          $panel.removeClass("animate");
          $headerCloak.removeClass("animate");
        }, 200);
      }
      $panel.css({ right: "", left: "" });
      $headerCloak.css("opacity", 0.5);
      this._animate = false;
    });
  }
});

export default SiteHeaderComponent;

function applyFlaggedProperties() {
  const args = _flagProperties.slice();
  args.push(
    function() {
      this.queueRerender();
    }.on("init")
  );

  SiteHeaderComponent.reopen({
    _flagsChanged: Ember.observer.apply(this, args)
  });
}

addFlagProperty("currentUser.site_flagged_posts_count");
addFlagProperty("currentUser.post_queue_new_count");

export { addFlagProperty, applyFlaggedProperties };

export function headerHeight() {
  const $header = $("header.d-header");
  const headerOffset = $header.offset();
  const headerOffsetTop = headerOffset ? headerOffset.top : 0;
  return parseInt(
    $header.outerHeight() + headerOffsetTop - $(window).scrollTop()
  );
}

export function headerTop() {
  const $header = $("header.d-header");
  const headerOffset = $header.offset();
  const headerOffsetTop = headerOffset ? headerOffset.top : 0;
  return parseInt(headerOffsetTop - $(window).scrollTop());
}
