import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";
import Composer from "discourse/models/composer";
import afterTransition from "discourse/lib/after-transition";
import positioningWorkaround from "discourse/lib/safari-hacks";
import { headerHeight } from "discourse/components/site-header";
import KeyEnterEscape from "discourse/mixins/key-enter-escape";

export default Ember.Component.extend(KeyEnterEscape, {
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

  @computed("currentUser.primary_group_name")
  currentUserPrimaryGroupClass(primaryGroupName) {
    return primaryGroupName && `group-${primaryGroupName}`;
  },

  @computed("composer.composeState")
  composeState(composeState) {
    return composeState || Composer.CLOSED;
  },

  movePanels(sizePx) {
    $("#main-outlet").css("padding-bottom", sizePx);

    // signal the progress bar it should move!
    this.appEvents.trigger("composer:resized");
  },

  @observes(
    "composeState",
    "composer.action",
    "composer.canEditTopicFeaturedLink"
  )
  resize() {
    Ember.run.scheduleOnce("afterRender", () => {
      if (!this.element || this.isDestroying || this.isDestroyed) {
        return;
      }

      const h = $("#reply-control").height() || 0;
      this.movePanels(h + "px");
    });
  },

  keyUp() {
    this.typed();

    const lastKeyUp = new Date();
    this._lastKeyUp = lastKeyUp;

    // One second from now, check to see if the last key was hit when
    // we recorded it. If it was, the user paused typing.
    Ember.run.cancel(this._lastKeyTimeout);
    this._lastKeyTimeout = Ember.run.later(() => {
      if (lastKeyUp !== this._lastKeyUp) {
        return;
      }
      this.appEvents.trigger("composer:find-similar");
    }, 1000);
  },

  @observes("composeState")
  disableFullscreen() {
    if (
      this.get("composeState") !== Composer.OPEN &&
      positioningWorkaround.blur
    ) {
      positioningWorkaround.blur();
    }
  },

  didInsertElement() {
    this._super(...arguments);
    const $replyControl = $("#reply-control");
    const resize = () => Ember.run(() => this.resize());

    $replyControl.DivResizer({
      resize,
      maxHeight: winHeight => winHeight - headerHeight(),
      onDrag: sizePx => this.movePanels(sizePx)
    });

    const triggerOpen = () => {
      if (this.get("composer.composeState") === Composer.OPEN) {
        this.appEvents.trigger("composer:opened");
      }
    };
    triggerOpen();

    afterTransition($replyControl, () => {
      resize();
      triggerOpen();
    });
    positioningWorkaround(this.$());

    this.appEvents.on("composer:resize", this, this.resize);
  },

  willDestroyElement() {
    this._super(...arguments);
    this.appEvents.off("composer:resize", this, this.resize);
  },

  click() {
    this.openIfDraft();
  }
});
