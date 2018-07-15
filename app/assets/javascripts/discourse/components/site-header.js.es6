import MountWidget from "discourse/components/mount-widget";
import { observes } from "ember-addons/ember-computed-decorators";
import Docking from "discourse/mixins/docking";
import PanEvents from "discourse/mixins/pan-events";

const _flagProperties = [];
function addFlagProperty(prop) {
  _flagProperties.pushObject(prop);
}

const PANEL_BODY_MARGIN = 30;

const SiteHeaderComponent = MountWidget.extend(Docking, PanEvents, {
  widget: "header",
  docAt: null,
  dockedHeader: null,
  animate: false,
  isPanning: false,
  panMenuOrigin: "right",
  panMenuOffset: 0,
  _topic: null,

  @observes(
    "currentUser.unread_notifications",
    "currentUser.unread_private_messages"
  )
  notificationsChanged() {
    this.queueRerender();
  },

  _panOpenClose(offset, velocity, direction) {
    const $window = $(window);
    const windowWidth = parseInt($window.width());
    const $menuPanels = $(".menu-panel");
    direction === "close" ? (offset += velocity) : (offset -= velocity);
    const menuOrigin = this.get("panMenuOrigin");
    $menuPanels.each((idx, panel) => {
      const $panel = $(panel);
      const $headerCloak = $(".header-cloak");
      $panel.css(menuOrigin, -offset);
      $headerCloak.css("opacity", Math.min(0.5, (300 - offset) / 600));
      if (offset > windowWidth) {
        $panel.css(menuOrigin, -windowWidth);
        this.set("animate", true);
        this.eventDispatched("dom:clean", "header");
        this.set("panMenuOffset", 0);
      } else if (offset <= 0) {
        $panel.css("right", "");
        $panel.css("left", "");
        this.set("panMenuOffset", 0);
      } else {
        Ember.run.later(
          () => this._panOpenClose(offset, velocity, direction),
          20
        );
      }
    });
  },

  _shouldPanClose(e) {
    const panMenuOrigin = this.get("panMenuOrigin");
    const panMenuOffset = this.get("panMenuOffset");
    if (panMenuOrigin === "right" && panMenuOffset === 0) {
      return (e.deltaX > 200 && e.velocityX > -0.15) || e.velocityX > 0.15;
    } else if (panMenuOrigin === "left" && panMenuOffset === 0) {
      return (e.deltaX < -200 && e.velocityX < 0.15) || e.velocityX < -0.15;
    } else if (panMenuOrigin === "right" && panMenuOffset !== 0) {
      return (e.deltaX > 200 && e.velocityX > -0.15) || e.velocityX > 0.15;
    } else if (panMenuOrigin === "left" && panMenuOffset !== 0) {
      return (e.deltaX < -200 && e.velocityX < 0.15) || e.velocityX < -0.15;
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
      this.set("isPanning", true);
    } else if (
      center.x < 30 &&
      !this.$(".menu-panel").length &&
      e.direction === "right"
    ) {
      this.setProperties({
        animate: false,
        panMenuOrigin: "left",
        panMenuOffset: -300,
        isPanning: true
      });
      this.eventDispatched("toggleHamburger", "header");
    } else if (
      windowWidth - center.x < 30 &&
      !this.$(".menu-panel").length &&
      e.direction === "left"
    ) {
      this.setProperties({
        animate: false,
        panMenuOrigin: "right",
        panMenuOffset: -300,
        isPanning: true
      });
      this.eventDispatched("toggleUserMenu", "header");
    } else {
      this.set("isPanning", false);
    }
  },

  panEnd(e) {
    if (!this.get("isPanning")) {
      return;
    }
    this.set("isPanning", false);
    const $menuPanels = $(".menu-panel");
    $menuPanels.each((idx, panel) => {
      const $panel = $(panel);
      let offset = $panel.css("right");
      if (this.get("panMenuOrigin") === "left") {
        offset = $panel.css("left");
      }
      offset = Math.abs(parseInt(offset));
      if (this._shouldPanClose(e)) {
        this._panOpenClose(offset, 40, "close");
      } else {
        this._panOpenClose(offset, 40, "open");
      }
    });
  },

  panMove(e) {
    if (!this.get("isPanning")) {
      return;
    }
    const $menuPanels = $(".menu-panel");
    const panMenuOffset = this.get("panMenuOffset");
    $menuPanels.each((idx, panel) => {
      const $panel = $(panel);
      const $headerCloak = $(".header-cloak");
      if (this.get("panMenuOrigin") === "right") {
        const pxClosed = Math.min(0, -e.deltaX + panMenuOffset);
        $panel.css("right", pxClosed);
        $headerCloak.css("opacity", Math.min(0.5, (300 + pxClosed) / 600));
      } else {
        const pxClosed = Math.min(0, e.deltaX + panMenuOffset);
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
    this._topic = topic;
    this.queueRerender();
  },

  willRender() {
    if (this.get("currentUser.staff")) {
      $("body").addClass("staff");
    }
  },

  didInsertElement() {
    this._super();
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
    this._super();
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
      this.set("animate", true);
      return;
    }

    const $window = $(window);
    const windowWidth = parseInt($window.width());

    const headerWidth = $("#main-outlet .container").width() || 1100;
    const remaining = parseInt((windowWidth - headerWidth) / 2);
    const viewMode = remaining < 50 ? "slide-in" : "drop-down";
    const animate = this.get("animate");

    $menuPanels.each((idx, panel) => {
      const $panel = $(panel);
      const $headerCloak = $(".header-cloak");
      let panMenuOffset = this.get("panMenuOffset");
      let width = parseInt($panel.attr("data-max-width") || 300);
      if (windowWidth - width < 50) {
        width = windowWidth - 50;
      }
      if (panMenuOffset) {
        this.set("panMenuOffset", -width);
      }

      $panel
        .removeClass("drop-down")
        .removeClass("slide-in")
        .addClass(viewMode);
      if (animate || panMenuOffset !== 0) {
        $headerCloak.css("opacity", 0);
        if (
          this.site.mobileView &&
          $panel.parent(".hamburger-panel").length > 0
        ) {
          this.set("panMenuOrigin", "left");
          $panel.css("left", -windowWidth);
        } else {
          this.set("panMenuOrigin", "right");
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

        const menuTop = this.site.mobileView ? 0 : headerHeight();

        let height;
        const winHeight = $(window).height() - 16;
        height = winHeight - menuTop;

        if ($panelBody.prop("style").height !== "100%") {
          $panelBody.height("100%");
        }
        if (style.top !== menuTop + "px" || style.height !== height) {
          $panel.css({ top: menuTop + "px", height });
        }
        $("body").removeClass("drop-down-mode");
      }

      $panel.width(width);
      if (animate) {
        $panel.addClass("animate");
        $headerCloak.addClass("animate");
        Ember.run.later(() => {
          $panel.removeClass("animate");
          $headerCloak.removeClass("animate");
        }, 200);
      }
      $panel.css("right", "");
      $panel.css("left", "");
      $headerCloak.css("opacity", 0.5);
      this.set("animate", false);
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
