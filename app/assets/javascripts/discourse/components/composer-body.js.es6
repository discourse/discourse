import { throttle } from "@ember/runloop";
import { run } from "@ember/runloop";
import { cancel } from "@ember/runloop";
import { scheduleOnce } from "@ember/runloop";
import { later } from "@ember/runloop";
import Component from "@ember/component";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import Composer from "discourse/models/composer";
import afterTransition from "discourse/lib/after-transition";
import positioningWorkaround from "discourse/lib/safari-hacks";
import { headerHeight } from "discourse/components/site-header";
import KeyEnterEscape from "discourse/mixins/key-enter-escape";
import { iOSWithVisualViewport } from "discourse/lib/utilities";

const START_EVENTS = "touchstart mousedown";
const DRAG_EVENTS = "touchmove mousemove";
const END_EVENTS = "touchend mouseup";

const MIN_COMPOSER_SIZE = 240;
const THROTTLE_RATE = 20;

function mouseYPos(e) {
  return e.clientY || (e.touches && e.touches[0] && e.touches[0].clientY);
}

export default Component.extend(KeyEnterEscape, {
  elementId: "reply-control",

  classNameBindings: [
    "composer.creatingPrivateMessage:private-message",
    "composeState",
    "composer.loading",
    "composer.canEditTitle:edit-title",
    "composer.createdPost:created-post",
    "composer.creatingTopic:topic",
    "composer.whisper:composing-whisper",
    "composer.sharedDraft:composing-shared-draft",
    "showPreview:show-preview:hide-preview",
    "currentUserPrimaryGroupClass"
  ],

  @discourseComputed("currentUser.primary_group_name")
  currentUserPrimaryGroupClass(primaryGroupName) {
    return primaryGroupName && `group-${primaryGroupName}`;
  },

  @discourseComputed("composer.composeState")
  composeState(composeState) {
    return composeState || Composer.CLOSED;
  },

  movePanels(size) {
    $("#main-outlet").css("padding-bottom", size ? size : "");

    // signal the progress bar it should move!
    this.appEvents.trigger("composer:resized");
  },

  @observes(
    "composeState",
    "composer.action",
    "composer.canEditTopicFeaturedLink"
  )
  resize() {
    scheduleOnce("afterRender", () => {
      if (!this.element || this.isDestroying || this.isDestroyed) {
        return;
      }

      const h = $("#reply-control:not(.saving)").height() || 0;
      this.movePanels(h);
    });
  },

  keyUp() {
    this.typed();

    const lastKeyUp = new Date();
    this._lastKeyUp = lastKeyUp;

    // One second from now, check to see if the last key was hit when
    // we recorded it. If it was, the user paused typing.
    cancel(this._lastKeyTimeout);
    this._lastKeyTimeout = later(() => {
      if (lastKeyUp !== this._lastKeyUp) {
        return;
      }
      this.appEvents.trigger("composer:find-similar");
    }, 1000);
  },

  @observes("composeState")
  disableFullscreen() {
    if (this.composeState !== Composer.OPEN && positioningWorkaround.blur) {
      positioningWorkaround.blur();
    }
  },

  setupComposerResizeEvents() {
    const $composer = $(this.element);
    const $grippie = $(this.element.querySelector(".grippie"));
    const $document = $(document);
    let origComposerSize = 0;
    let lastMousePos = 0;

    const performDrag = event => {
      $composer.trigger("div-resizing");
      $composer.addClass("clear-transitions");
      const currentMousePos = mouseYPos(event);
      let size = origComposerSize + (lastMousePos - currentMousePos);

      const winHeight = $(window).height();
      size = Math.min(size, winHeight - headerHeight());
      size = Math.max(size, MIN_COMPOSER_SIZE);
      this.movePanels(size);
      $composer.height(size);
    };

    const throttledPerformDrag = (event => {
      event.preventDefault();
      throttle(this, performDrag, event, THROTTLE_RATE);
    }).bind(this);

    const endDrag = () => {
      $document.off(DRAG_EVENTS, throttledPerformDrag);
      $document.off(END_EVENTS, endDrag);
      $composer.removeClass("clear-transitions");
      $composer.focus();
    };

    $grippie.on(START_EVENTS, event => {
      event.preventDefault();
      origComposerSize = $composer.height();
      lastMousePos = mouseYPos(event);
      $document.on(DRAG_EVENTS, throttledPerformDrag);
      $document.on(END_EVENTS, endDrag);
    });

    if (iOSWithVisualViewport()) {
      this.viewportResize();
      window.visualViewport.addEventListener("resize", this.viewportResize);
    }
  },

  viewportResize() {
    const composerVH = window.visualViewport.height * 0.01;

    document.documentElement.style.setProperty(
      "--composer-vh",
      `${composerVH}px`
    );
  },

  didInsertElement() {
    this._super(...arguments);
    this.setupComposerResizeEvents();

    const resize = () => run(() => this.resize());
    const triggerOpen = () => {
      if (this.get("composer.composeState") === Composer.OPEN) {
        this.appEvents.trigger("composer:opened");
      }
    };
    triggerOpen();

    afterTransition($(this.element), () => {
      resize();
      triggerOpen();
    });
    positioningWorkaround($(this.element));
  },

  willDestroyElement() {
    this._super(...arguments);
    this.appEvents.off("composer:resize", this, this.resize);
    if (iOSWithVisualViewport()) {
      window.visualViewport.removeEventListener("resize", this.viewportResize);
    }
  },

  click() {
    this.openIfDraft();
  }
});
